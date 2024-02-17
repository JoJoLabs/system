{ pkgs, ... }: 
{
  environment.systemPackages = with pkgs; [
    dmidecode
  ];
  systemd.services.inception = {
    description = "set hostname based on system uuid";
    wantedBy = [ "multi-user.target" ];
    RequiredBy = [ "network.service" ];
    path = [ "/run/current-system/sw/" ];
    script = with pkgs; ''
      uuid=$(${pkgs.dmidecode}/bin/dmidecode -- -s system-uuid | base64 | head -c 8 | tr '[:upper:]' '[:lower:]')
      hostnamectl set-hostname nixos-${uuid}
    '';
    serviceConfig = {
      Type = "oneshot";
    };
};
}