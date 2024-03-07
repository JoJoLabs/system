{ config, self, pkgs, lib, ... }:
with lib;
let
  top = config.services.kubernetes;
  toBase64 = text: let
    inherit (lib) sublist mod stringToCharacters concatMapStrings;
    inherit (lib.strings) charToInt;
    inherit (builtins) substring foldl' genList elemAt length concatStringsSep stringLength;
    lookup = stringToCharacters "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    sliceN = size: list: n: sublist (n * size) size list;
    pows = [(64 * 64 * 64) (64 * 64) 64 1];
    intSextets = i: map (j: mod (i / j) 64) pows;
    compose = f: g: x: f (g x);
    intToChar = elemAt lookup;
    convertTripletInt = sliceInt: concatMapStrings intToChar (intSextets sliceInt);
    sliceToInt = foldl' (acc: val: acc * 256 + val) 0;
    convertTriplet = compose convertTripletInt sliceToInt;
    join = concatStringsSep "";
    convertLastSlice = slice: let
      len = length slice;
    in
      if len == 1
      then (substring 0 2 (convertTripletInt ((sliceToInt slice) * 256 * 256))) + "=="
      else if len == 2
      then (substring 0 3 (convertTripletInt ((sliceToInt slice) * 256))) + "="
      else "";
    len = stringLength text;
    nFullSlices = len / 3;
    bytes = map charToInt (stringToCharacters text);
    tripletAt = sliceN 3 bytes;
    head = genList (compose convertTriplet tripletAt) nFullSlices;
    tail = convertLastSlice (tripletAt nFullSlices);
  in
    join (head ++ [tail]);
  clusterAdminKubeconfig = 
    if elem "master" top.roles then
      with top.pki.certs.clusterAdmin;
        top.lib.mkKubeConfig "cluster-admin" {
          server = top.apiserverAddress;
          certFile = cert;
          keyFile = key;
        }
    else 
      null;
  calico-conf = pkgs.writeTextFile { 
    name = "10-calico.conflist";
    text = builtins.toJSON {
      name = "k8s-pod-network";
      cniVersion = "0.3.1";
      plugins = [
        {
          type = "calico";
          log_level = "info";
          datastore_type = "kubernetes";
          mtu = 1500;
          ipam = { type = "calico-ipam"; };
          policy = { type = "k8s"; };
          kubernetes = { kubeconfig = "/etc/cni/net.d/calico-kubeconfig"; };
        }
      ];
    };
  };
  calico-kubeconfig = pkgs.writeTextFile {
    name = "calico-kubeconfig";
    text = builtins.toJSON {
      apiVersion = "v1";
      kind = "Config";
      clusters = [{
        name = "local";
        cluster.certificate-authority = "${top.secretsPath}/ca.pem";
        cluster.server = top.apiserverAddress;
      }];
      users = [{
        user = {
          name = "calico-cni";
          client-certificate = "${top.secretsPath}/calico-cni.pem";
          client-key = "${top.secretsPath}/calico-cni-key.pem";
        };
      }];
      contexts = [{
        context = {
          cluster = "local";
          user = "calico-cni";
        };
        name = "local";
      }];
      current-context = "local";
    };
  };
in
{

  services.kubernetes.kubelet = {
    cni.configDir = "/etc/cni/calico";
  };

  environment.etc."cni/calico/10-calico.conflist" = {
    source = calico-conf;
    mode = "0755";
  };

  services.kubernetes.pki.certs = {
    typha = top.lib.mkCert {
      name = "typha";
      CN = "calico-typha";
      action = "systemctl restart typha-bootstrap.service";
    };
    calico-node = top.lib.mkCert {
      name = "calico-node";
      CN = "calico-node";
      action = "systemctl restart typha-bootstrap.service";
    };
  };

  systemd.services.typha-bootstrap = {
    description = "Calico Typha bootstrapper";
    after = [ "certmgr.service" ];
    script = with pkgs.openssl;
    concatStringsSep "\n" [
      ''
      KUBECONFIG=${calico-kubeconfig} ${top.package}/bin/kubectl config view --flatten > /etc/cni/calico/calico-kubeconfig
      ''
      (optionalString (elem "master" top.roles) ''
      if [ ! -f ${top.secretsPath}/typhaca.key ]; then
        ${pkgs.openssl}/bin/openssl req -x509 -newkey rsa:4096 \
                  -keyout ${top.secretsPath}/typhaca.key \
                  -nodes \
                  -out ${top.secretsPath}/typhaca.crt \
                  -subj "/CN=Calico Typha CA" \
                  -days 365
        ${pkgs.openssl}/bin/openssl req -newkey rsa:4096 \
                  -keyout ${top.secretsPath}/typha.key \
                  -nodes \
                  -out ${top.secretsPath}/typha.csr \
                  -subj "/CN=calico-typha"
        ${pkgs.openssl}/bin/openssl x509 -req -in ${top.secretsPath}/typha.csr \
                  -CA ${top.secretsPath}/typhaca.crt \
                  -CAkey ${top.secretsPath}/typhaca.key \
                  -CAcreateserial \
                  -out ${top.secretsPath}/typha.crt \
                  -days 365
        ${pkgs.openssl}/bin/openssl req -newkey rsa:4096 \
                  -keyout ${top.secretsPath}/calico-node.key \
                  -nodes \
                  -out ${top.secretsPath}/calico-node.csr \
                  -subj "/CN=calico-node"
        ${pkgs.openssl}/bin/openssl x509 -req -in ${top.secretsPath}/calico-node.csr \
                  -CA ${top.secretsPath}/typhaca.crt \
                  -CAkey ${top.secretsPath}/typhaca.key \
                  -CAcreateserial \
                  -out ${top.secretsPath}/calico-node.crt \
                  -days 365
      fi

      export KUBECONFIG=${clusterAdminKubeconfig}
      ${top.package}/bin/kubectl delete secret -n kube-system calico-typha-certs --ignore-not-found
      ${top.package}/bin/kubectl delete secret -n kube-system calico-node-certs --ignore-not-found
      ${top.package}/bin/kubectl delete configmap -n kube-system calico-typha-ca --ignore-not-found
      ${top.package}/bin/kubectl create secret generic -n kube-system calico-typha-certs --from-file=typha.key=${top.secretsPath}/typha.key --from-file=typha.crt=${top.secretsPath}/typha.crt
      ${top.package}/bin/kubectl create configmap -n kube-system calico-typha-ca --from-file=typhaca.crt=${top.secretsPath}/typhaca.crt
      ${top.package}/bin/kubectl create secret generic -n kube-system calico-node-certs --from-file=calico-node.key=${top.secretsPath}/calico-node.key --from-file=calico-node.crt=${top.secretsPath}/calico-node.crt
    '')
    ];
    serviceConfig = {
      RestartSec = "10s";
      Restart = "on-failure";
    };
  };

  services.kubernetes.addonManager.bootstrapAddons = {
    calico-typha-sa = {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = { name = "calico-typha"; namespace = "kube-system"; };
    };
    calico-typha-cr = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata = { name = "calico-typha"; };
      rules = [{
        apiGroups = [ "" ];
        resources = [ "pods" "nodes" "namespaces" "serviceaccounts" "endpoints" "services" ];
        verbs = [ "get" "list" "watch"];
      }
      {
        apiGroups = [ "networking.k8s.io" ];
        resources = [ "networkpolicies" ];
        verbs = [ "watch" "list" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [
          "globalfelixconfigs"
          "felixconfigurations"
          "bgppeers"
          "globalbgpconfigs"
          "bgpconfigurations"
          "ippools"
          "ipamblocks"
          "globalnetworkpolicies"
          "globalnetworksets"
          "networkpolicies"
          "clusterinformations"
          "hostendpoints"
          "blockaffinities"
          "networksets"
          "caliconodestatuses"
          "bgpfilters"
        ];
        verbs = [ "get" "list" "watch" ];
      }
      {
        apiGroups = [ "discovery.k8s.io" ];
        resources = [ "endpointslices" ];
        verbs = [ "watch" "list" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [ "ippools" "felixconfigurations" "clusterinformations" ];
        verbs = [ "get" "create" "update" ];
      }];
    };
    calico-typha-crb = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata = { name = "calico-typha"; };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "calico-typha";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "calico-typha";
        namespace = "kube-system";
      }];
    };
    calico-typha-deployment = {
      apiVersion = "apps/v1";
      kind = "Deployment";
      metadata = {
        name = "calico-typha";
        namespace = "kube-system";
        labels = {
          k8s-app = "calico-typha";
        };
      };
      spec = {
        replicas = 3;
        revisionHistoryLimit = 2;
        selector = { matchLabels = { k8s-app = "calico-typha"; }; };
        template = {
          metadata = {
            labels = { k8s-app = "calico-typha"; };
            annotations = { "cluster-autoscaler.kubernetes.io/safe-to-evict" = "true"; };
          };
          spec = {
            hostNetwork = true;
            tolerations = [{ key = "CriticalAddonsOnly"; operator = "Exists"; }];
            serviceAccountName = "calico-typha";
            priorityClassName = "system-cluster-critical";
            containers = [
              {
                image = "calico/typha:v3.27.2";
                name = "calico-typha";
                ports = [{
                  containerPort = 5473;
                  name = "calico-typha";
                  protocol = "TCP";
                }];
                env = [
                  {
                    name = "TYPHA_LOGFILEPATH";
                    value = "none";
                  }
                  {
                    name = "TYPHA_LOGSEVERITYSYS";
                    value = "none";
                  }
                  {
                    name = "TYPHA_CONNECTIONREBALANCINGMODE";
                    value = "kubernetes";
                  }
                  {
                    name = "TYPHA_DATASTORETYPE";
                    value = "kubernetes";
                  }
                  {
                    name = "TYPHA_HEALTHENABLED";
                    value = "true";
                  }
                  {
                    name = "TYPHA_CAFILE";
                    value = "/calico-typha-ca/typhaca.crt";
                  }
                  {
                    name = "TYPHA_CLIENTCN";
                    value = "calico-node";
                  }
                  {
                    name = "TYPHA_SERVERCERTFILE";
                    value = "/calico-typha-certs/typha.crt";
                  }
                  {
                    name = "TYPHA_SERVERKEYFILE";
                    value = "/calico-typha-certs/typha.key";
                  }
                ];
                livenessProbe = {
                  httpGet = {
                    path = "/liveness";
                    port = 9098;
                    host = "localhost";
                  };
                  periodSeconds = 30;
                  initialDelaySeconds = 30;
                };
                readinessProbe = {
                  httpGet = {
                    path = "/readiness";
                    port = 9098;
                    host = "localhost";
                  };
                  periodSeconds = 10;
                };
                volumeMounts = [
                  {
                    name = "calico-typha-ca";
                    mountPath = "/calico-typha-ca";
                    readOnly = true;
                  }
                  {
                    name = "calico-typha-certs";
                    mountPath = "/calico-typha-certs";
                    readOnly = true;
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "calico-typha-ca";
                configMap = {
                  name = "calico-typha-ca";
                };
              }
              {
                name = "calico-typha-certs";
                secret = { secretName = "calico-typha-certs"; };
              }
            ];
          };
        };
      };
    };
    calico-typha-service = {
      apiVersion = "v1";
      kind = "Service";
      metadata = {
        name = "calico-typha";
        namespace = "kube-system";
        labels = { k8s-app = "calico-typha"; };
      };
      spec = {
        ports = [{
          port = 5473;
          protocol = "TCP";
          targetPort = "calico-typha";
          name = "calico-typha";
        }];
        selector = { k8s-app = "calico-typha"; };
      };
    };
    calico-node-sa = {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = { name = "calico-node"; namespace = "kube-system"; };
    };
    calico-node-cr = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata = { name = "calico-node"; };
      rules = [{
        apiGroups = [ "" ];
        resources = [ "pods" "nodes" "namespaces" "configmaps" ];
        verbs = [ "get" ];
      }
      {
        apiGroups = [ "discovery.k8s.io" ];
        resources = [ "endpointslices" ];
        verbs = [ "watch" "list" ];
      }
      {
        apiGroups = [ "" ];
        resources = [ "endpoints" "services" ];
        verbs = [ "get" "watch" "list" ];
      }
      {
        apiGroups = [""];
        resources = [ "nodes/status" ];
        verbs = [ "patch" "update" ];
      }
      {
        apiGroups = ["networking.k8s.io"];
        resources = [ "networkpolicies" ];
        verbs = [ "watch" "list" ];
      }
      {
        apiGroups = [""];
        resources = [ "pods" "namespaces" "serviceaccounts" ];
        verbs = [ "watch" "list" ];
      }
      {
        apiGroups = [""];
        resources = [ "pods/status" ];
        verbs = [ "patch" ];
      }
      {
        apiGroups = [""];
        resources = [ "serviceaccounts/token" ];
        verbs = [ "create" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [
          "globalfelixconfigs"
          "felixconfigurations"
          "bgppeers"
          "globalbgpconfigs"
          "bgpconfigurations"
          "ippools"
          "ipamblocks"
          "globalnetworkpolicies"
          "globalnetworksets"
          "networkpolicies"
          "networksets"
          "clusterinformations"
          "hostendpoints"
          "blockaffinities"
        ];
        verbs = [ "get" "list" "watch" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [ "ippools" "felixconfigurations" "clusterinformations" ];
        verbs = [ "create" "update" ];
      }
      {
        apiGroups = [ "" ];
        resources = [ "nodes" ];
        verbs = [ "get" "list" "watch" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [ "ipamconfigs" ];
        verbs = [ "get" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [ "blockaffinities" "ipamblocks" "ipamhandles" ];
        verbs = [ "get" "list" "create" "update" "delete" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [ "blockaffinities" ];
        verbs = [ "watch" ];
      }
      ];
    };
    calico-node-crb = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata = { name = "calico-node"; };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "calico-node";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "calico-node";
        namespace = "kube-system";
      }];
    };
    calico-node-ds = {
      kind = "DaemonSet";
      apiVersion = "apps/v1";
      metadata = { 
        name = "calico-node";
        namespace = "kube-system";
        labels = { k8s-app = "calico-node"; };
      };
      spec = {
        selector = { matchLabels = { k8s-app = "calico-node"; }; };
        updateStrategy = {
          type = "RollingUpdate";
          rollingUpdate = {
            maxUnavailable = 1;
          };
        };
        template = {
          metadata = { 
            labels = { k8s-app = "calico-node"; };
          };
          spec = {
            nodeSelector = {"kubernetes.io/os" = "linux"; };
            hostNetwork = true;
            tolerations = [
              {
                effect = "NoSchedule";
                operator = "Exists";
              }
              {
                key = "CriticalAddonsOnly";
                operator = "Exists";
              }
              {
                effect = "NoExecute";
                operator = "Exists";
              }
            ];
            serviceAccountName = "calico-node";
            terminationGracePeriodSeconds = 0;
            priorityClassName = "system-node-critical";
            containers = [
              {
                name = "calico-node";
                image = "calico/node:v3.27.2";
                env = [
                  {
                    name = "DATASTORE_TYPE";
                    value = "kubernetes";
                  }
                  {
                    name = "FELIX_TYPHAK8SSERVICENAME";
                    value = "calico-typha";
                  }
                  {
                    name = "WAIT_FOR_DATASTORE";
                    value = "true";
                  }
                  {
                    name = "NODENAME";
                    valueFrom = { fieldRef = { fieldPath = "spec.nodeName"; }; };
                  }
                  {
                    name = "CALICO_NETWORKING_BACKEND";
                    value = "bird";
                  }
                  {
                    name = "CLUSTER_TYPE";
                    value = "k8s,bgp";
                  }
                  {
                    name = "IP";
                    value = "autodetect";
                  }
                  {
                    name = "CALICO_DISABLE_FILE_LOGGING";
                    value = "true";
                  }
                  {
                    name = "FELIX_DEFAULTENDPOINTTOHOSTACTION";
                    value = "ACCEPT";
                  }
                  {
                    name = "FELIX_IPV6SUPPORT";
                    value = "false";
                  }
                  {
                    name = "FELIX_LOGSEVERITYSCREEN";
                    value = "info";
                  }
                  {
                    name = "FELIX_HEALTHENABLED";
                    value = "true";
                  }
                  {
                    name = "FELIX_TYPHACAFILE";
                    value = "/calico-typha-ca/typhaca.crt";
                  }
                  {
                    name = "FELIX_TYPHACN";
                    value = "calico-typha";
                  }
                  {
                    name = "FELIX_TYPHACERTFILE";
                    value = "/calico-node-certs/calico-node.crt";
                  }
                  {
                    name = "FELIX_TYPHAKEYFILE";
                    value = "/calico-node-certs/calico-node.key";
                  }
                ];
                securityContext = { privileged = true; };
                resources = { requests = { cpu = "250m"; }; };
                lifecycle = { preStop = { exec = { command = [
                  "/bin/calico-node"
                  "-shutdown"
                ];};};};
                livenessProbe = {
                  httpGet = {
                    path = "/liveness";
                    port = 9099;
                    host = "localhost";
                  };
                  periodSeconds = 10;
                  initialDelaySeconds = 10;
                  failureThreshold = 6;
                };
                readinessProbe = {
                  exec = {
                    command = [
                      "/bin/calico-node"
                      "-bird-ready"
                      "-felix-ready"
                    ];
                  };
                  periodSeconds = 10;
                };
                volumeMounts = [
                  {
                    mountPath = "/lib/modules";
                    name = "lib-modules";
                    readOnly = true;
                  }
                  {
                    mountPath = "/run/xtables.lock";
                    name = "xtables-lock";
                    readOnly = false;
                  }
                  {
                    mountPath = "/var/run/calico";
                    name = "var-run-calico";
                    readOnly = false;
                  }
                  {
                    mountPath = "/var/lib/calico";
                    name = "var-lib-calico";
                    readOnly = false;
                  }
                  {
                    mountPath = "/var/run/nodeadgent";
                    name = "policysync";
                  }
                  {
                    mountPath = "/calico-typha-ca";
                    name = "calico-typha-ca";
                    readOnly = true;
                  }
                  {
                    mountPath = "/calico-node-certs";
                    name = "calico-node-certs";
                    readOnly = true;
                  }
                  {
                    mountPath =  "/host/opt/cni/bin";
                    name = "cni-bin-dir";
                  }
                  {
                    mountPath =  "/host/etc/cni/net.d";
                    name = "cni-net-dir";
                  }
                ];
              }
            ];
            volumes = [
              {
                name = "lib-modules";
                hostPath = { path = "/lib/modules"; };
              }
              {
                name = "var-run-calico";
                hostPath = { path = "/var/run/calico"; };
              }
              {
                name = "var-lib-calico";
                hostPath = { path = "/var/lib/calico"; };
              }
              {
                name = "xtables-lock";
                hostPath = {
                  path = "/run/xtables.lock";
                  type = "FileOrCreate";
                };
              }
              {
                name = "policysync";
                hostPath = {
                  type = "DirectoryOrCreate";
                  path = "/var/run/nodeagent";
                };
              }
              {
                name = "calico-typha-ca";
                configMap = {
                  name = "calico-typha-ca";
                };
              }
              {
                name = "calico-node-certs";
                secret = { secretName = "calico-node-certs"; };
              }
              {
                name = "cni-bin-dir";
                hostPath = { path = "/opt/cni/bin"; };
              }
              {
                name = "cni-net-dir";
                hostPath = { path = "/etc/cni/calico"; };
              }
            ];
          };
        };
      };
    };
    calico-cni-plugin-sa = {
      apiVersion = "v1";
      kind = "ServiceAccount";
      metadata = { name = "calico-cni-plugin"; namespace = "kube-system"; };
    };
    calico-cni-plugin-cr = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRole";
      metadata = { name = "calico-cni-plugin"; };
      rules = [{
        apiGroups = [ "" ];
        resources = [ "pods" "nodes" "namespaces" ];
        verbs = [ "get" ];
      }
      {
        apiGroups = [ "" ];
        resources = [ "pods/status" ];
        verbs = [ "patch" ];
      }
      {
        apiGroups = [ "crd.projectcalico.org" ];
        resources = [ "blockaffinities" "ipamblocks" "ipamhandles" "clusterinformations" "ippools" "ipreservations" "ipamconfigs" ];
        verbs = [ "get" "list" "create" "update" "delete" ];
      }];
    };
    calico-cni-plugin-crb = {
      apiVersion = "rbac.authorization.k8s.io/v1";
      kind = "ClusterRoleBinding";
      metadata = { name = "calico-cni-plugin"; };
      roleRef = {
        apiGroup = "rbac.authorization.k8s.io";
        kind = "ClusterRole";
        name = "calico-cni-plugin";
      };
      subjects = [{
        kind = "ServiceAccount";
        name = "calico-cni-plugin";
        namespace = "kube-system";
      }];
    };
  };
}