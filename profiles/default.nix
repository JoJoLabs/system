{...}: {
  user.name = "joris";
  flake.uri = "github:jojolabs/system#joris"
  hm = {imports = [./home-manager/default.nix];};
}
