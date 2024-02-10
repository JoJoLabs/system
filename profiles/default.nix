{ lib, ... }: {
  user.name = "joris";
  hm = {imports = [./home-manager/default.nix];};
  flakeURI = lib.mkdefault "github:jojolabs/system#joris@linux";
}
