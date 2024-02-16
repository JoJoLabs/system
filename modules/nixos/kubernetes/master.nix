{ config, pkgs, ... }:
let
  # When using easyCerts=true the IP Address must resolve to the master on creation.
  # So use simply 127.0.0.1 in that case. Otherwise you will have errors like this https://github.com/NixOS/nixpkgs/issues/59364
  kubeMasterIP = "10.25.25.2";
  kubeMasterHostname = "api.kube.jojolabs.cloud";
  kubeMasterAPIServerPort = 6443;
  # uid = pkgs.runCommand "uid" {} ''    
  #   ${pkgs.dmidecode}/bin/dmidecode -- -s system-uuid | base64 | head -c 8 | tr '[:upper:]' '[:lower:]' > $out
  # '';
in
{
  # packages for administration tasks
  environment.systemPackages = with pkgs; [
    kubectl
    kubernetes
    dmidecode
  ];

  networking.firewall = {
    enable = false;
    # allowedTCPPorts = [ 22 6443 8888 ];
  };

  services.kubernetes = {
    roles = ["master" "node"];
    masterAddress = kubeMasterHostname;
    apiserverAddress = "https://${kubeMasterHostname}:${toString kubeMasterAPIServerPort}";
    easyCerts = true;
    apiserver = {
      securePort = kubeMasterAPIServerPort;
      advertiseAddress = kubeMasterIP;
    };

    # use coredns
    addons.dns.enable = true;

    # needed if you use swap
    kubelet.extraOpts = "--fail-swap-on=false";
    kubelet.hostname = "master-uid";
  };
}