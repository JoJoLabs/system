{ config, self, pkgs, lib, ... }: {
  services.drbd.enable = true;
  boot.extraModprobeConfig = ''
    options drbd usermode_helper=disabled
  '';
  # environment.etc."modprobe.d/drbd.conf".source = pkgs.writeTextFile { 
  #   name = "drbd.conf";
  #   text = "options drbd usermode_helper=disabled";
  # };
  systemd.tmpfiles.rules = [
    "d /usr/src 0755 root root -"
  ];
}