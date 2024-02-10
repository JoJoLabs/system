{ lib, ... }: {
  imports = [ ./default.nix ];
  flakeURI = "github:jojolabs/system#kubemaster";
}
