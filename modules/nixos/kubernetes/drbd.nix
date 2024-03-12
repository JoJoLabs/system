{ config, self, pkgs, lib, ... }: {
  environment.systemPackages = [ (import ../pkgs/linux/drbd-mod/default.nix) ];
  services.udev.packages = [ (import ../pkgs/linux/drbd-mod/default.nix) ];
  services.drbd.enable = true;
  services.drbd.enable_helper = false;
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