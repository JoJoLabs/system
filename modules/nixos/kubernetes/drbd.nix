{ config, self, pkgs, lib, ... }: {
  boot.extraModulePackages = [ pkgs.drbd-mod ];
  
  boot.extraModprobeConfig = ''
    options drbd usermode_helper=disabled
  '';
  boot.kernelModules = [ "drbd" ];
  # environment.etc."modprobe.d/drbd.conf".source = pkgs.writeTextFile { 
  #   name = "drbd.conf";
  #   text = "options drbd usermode_helper=disabled";
  # };
  systemd.tmpfiles.rules = [
    "d /usr/src 0755 root root -"
  ];
}