{ hostname ? "nixos-worker", config, pkgs, lib, ... }:
let
  kubeMasterHostname = "api.kube.jojolabs.cloud";
  kubeMasterAPIServerPort = 6443;
in
{
  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    kompose
    kubectl
    kubernetes
    calico
  ];

  networking.hostName = hostname;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      443
      6443
      80
      8080
      15000
      15004
      15006
      15009
      15010
      15012
      15014
      15017
      15020
      15021
      15053
      15090
      2601
      22
    ];
    trustedInterfaces = [
      "enp1s0"
      "flannel.1"
      "mynet"
    ];
  };

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
  };
}
