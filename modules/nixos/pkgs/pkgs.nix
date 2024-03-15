{
  inputs,
  lib,
  pkgs,
  ...
}: {
  nixpkgs.overlays = [
    # channels
    (final: prev: {
      # expose other channels via overlays
      stable = import inputs.stable {inherit (prev) system;};
      small = import inputs.small {inherit (prev) system;};

      drbd-mod = pkgs.callPackage ./linux/drbd-mod { };
    })
  ];
}