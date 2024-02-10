{ lib, ... }: {
  include = [ ./default.nix ]
  flakeURI = "github:jojolabs/system#kubemaster"
}
