{ lib, ... }: {
  user.name = "joris";
  hm = {imports = [./home-manager/default.nix];};
  flakeURI = lib.mkDefault "github:jojolabs/system#joris@linux";
}
