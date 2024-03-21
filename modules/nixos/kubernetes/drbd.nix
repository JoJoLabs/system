{ config, self, pkgs, lib, ... }: {
  boot.extraModulePackages = [ pkgs.drbd-mod ];
  
  boot.extraModprobeConfig = ''
    options drbd usermode_helper=disabled
  '';
  boot.kernelModules = [ "drbd" ];
  
  systemd.tmpfiles.rules = [
    "d /usr/src 0755 root root -"
  ];
}