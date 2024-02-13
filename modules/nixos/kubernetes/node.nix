{ config, pkgs, lib, ... }:
let
  kubeMasterHostname = "api.kube.jojolabs.cloud";
  kubeMasterAPIServerPort = 6443;
  # kubeNodeHostname = lib.literalExpression "config.networking.fqdnOrHostName";
  kubeNodeHostname = "nixos";
  output = pkgs.runCommand "machineID" {} ''    
    head -c 16 /dev/urandom | base64 | head -c 8 > $out
  '';
in
{
  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes
  ];

  services.kubernetes = let
    api = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
  in
  {
    roles = ["node"];
    masterAddress = kubeMasterHostname;
    easyCerts = true;

    # point kubelet and other services to kube-apiserver
    kubelet.kubeconfig.server = api;
    apiserverAddress = api;

    # use coredns
    addons.dns.enable = true;

    # needed if you use swap
    kubelet.extraOpts = "--fail-swap-on=false";
    kubelet.hostname = "${kubeNodeHostname}-${builtins.readFile output}";
  };
}
