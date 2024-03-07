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
  clusterAdminKubeconfig = with top.pki.certs.clusterAdmin;
    top.lib.mkKubeConfig "cluster-admin" {
      server = top.apiserverAddress;
      certFile = cert;
      keyFile = key;
    };
in
{
  services.kubernetes.pki.certs = {
    # typhaca = top.lib.mkCert {
    #   name = "typhaca";
    #   CN = "Calico Typha CA";
    #   action = "systemctl restart typha-bootstrap.service";
    # };
    typha = top.lib.mkCert {
      # caCert = "${top.secretsPath}/typhaca.pem";
      name = "typha";
      CN = "calico-typha";
      action = "systemctl restart typha-bootstrap.service";
    };
  };

  systemd.services.typha-bootstrap = {
    description = "Calico Typha bootstrapper";
    after = [ "certmgr.service" ];
    script = concatStringsSep "\n" [''
      export KUBECONFIG=${clusterAdminKubeconfig}
      ${top.package}/bin/kubectl delete secret -n kube-system calico-typha-certs --ignore-not-found
      ${top.package}/bin/kubectl delete configmap -n kube-system calico-typha-ca --ignore-not-found
      ${top.package}/bin/kubectl create secret generic -n kube-system calico-typha-certs --from-file=typha.key=${top.secretsPath}/typha-key.pem --from-file=typha.crt=${top.secretsPath}/typha.pem
      ${top.package}/bin/kubectl create configmap -n kube-system calico-typha-ca --from-file=typhaca.crt=${top.secretsPath}/ca.pem
    ''
    ];
    serviceConfig = {
      RestartSec = "10s";
      Restart = "on-failure";
    };
  };

  services.kubernetes.addonManager.bootstrapAddons = {
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
        ];
        verbs = [ "get" "list" "watch" ];
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
                image = "calico/typha:v3.8.0";
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
  };
}