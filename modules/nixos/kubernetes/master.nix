{ config, pkgs, ... }:
let
  # When using easyCerts=true the IP Address must resolve to the master on creation.
  # So use simply 127.0.0.1 in that case. Otherwise you will have errors like this https://github.com/NixOS/nixpkgs/issues/59364
  kubeMasterIP = "10.25.25.2";
  kubeMasterHostname = "api.kube.jojolabs.cloud";
  kubeMasterAPIServerPort = 6443;
in
{
  imports = [ ./calico.nix ];
  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes
    calicoctl
  ];

  networking.hostName = "nixos-master";
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      443
      6443
      80
      5473
      8080
      8888
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
      9099
      9098
      2601
      22
    ];
    trustedInterfaces = [
      "enp1s0"
    ];
  };

  services.kubernetes = {
    roles = ["master" "node"];
    masterAddress = kubeMasterHostname;
    apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
    easyCerts = true;
    apiserver = {
      securePort = kubeMasterAPIServerPort;
      advertiseAddress = kubeMasterIP;
      allowPrivileged = true;
    };

    # use coredns
    addons.dns.enable = true;

    # needed if you use swap
    kubelet.extraOpts = "--fail-swap-on=false";
  };
}