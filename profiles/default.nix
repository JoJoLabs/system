{...}: {
  user.name = "joris";
  flake.uri = "github:jojolabs/system#joris@linux"
  hm = {imports = [./home-manager/default.nix];};
}
