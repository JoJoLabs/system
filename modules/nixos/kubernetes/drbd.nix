{ config, self, pkgs, lib, ... }: {
  services.drbd.enable = true;
  environment.etc."modprobe.d/drbd.conf".source = "options drbd usermode_helper=disabled";
}