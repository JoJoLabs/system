{ lib, noSysDirs, config, overlays }:
res: pkgs: super:

with pkgs;

{
  drbd-mod = callPackage "./pkgs/linux/drbd-mod" {} ;
}