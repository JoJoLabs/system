{ config, self, pkgs, lib, ... }:
with lib;
let
  top = config.services.kubernetes;
  crd-file = (builtins.readFile "${toString self}/modules/nixos/kubernetes/calico-crds.json");
in
{
  imports = [ ./typha.nix ];
  environment.systemPackages = with pkgs; [
    calicoctl
    calico-cni-plugin
  ];

  services.kubernetes.flannel.enable = false;

  services.kubernetes.pki.certs = {
    calicoclient = top.lib.mkCert {
      name = "calico-cni";
      CN = "calico-cni";
    };
  };

  services.kubernetes.kubelet = {
      cni.configDir =(pkgs.buildEnv {
        name = "kubernetes-cni-config";
        paths = [
          (pkgs.writeTextDir "10-calico.conflist" (builtins.toJSON {
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
          }))
          (pkgs.writeTextDir "calico-kubeconfig" (builtins.toJSON {
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
          }))
        ];
      });
    };

  services.kubernetes.kubelet.cni.packages = [pkgs.calico-cni-plugin];

  services.kubernetes.addonManager.bootstrapAddons = mkMerge [ 
    (builtins.fromJSON crd-file)
    (mkIf ((elem "RBAC" top.apiserver.authorizationMode)) {
      calico-cr = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRole";
        metadata = { name = "calico-cni"; };
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
          resources = [ "blockaffinities" "ipamblocks" "ipamhandles" ];
          verbs = [ "get" "list" "create" "update" "delete" ];
        }
        {
          apiGroups = [ "crd.projectcalico.org" ];
          resources = [ "ipamconfigs" "clusterinformations" "ippools" ];
          verbs = [ "get" "list" ];
        }];
      };
      calico-crb = {
        apiVersion = "rbac.authorization.k8s.io/v1";
        kind = "ClusterRoleBinding";
        metadata = { name = "calico-cni"; };
        roleRef = {
          apiGroup = "rbac.authorization.k8s.io";
          kind = "ClusterRole";
          name = "calico-cni";
        };
        subjects = [{
          kind = "User";
          name = "calico-cni";
        }];
      };
    })
  ];
  services.kubernetes.addonManager.addons = {
    calico-ippool = {
      apiVersion = "crd.projectcalico.org/v1";
      kind = "IPPool";
      metadata = { name = "default"; };
      spec = {
        cidr = top.apiserver.serviceClusterIpRange;
      };
    };
  };

}