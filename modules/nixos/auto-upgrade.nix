{ config, lib, ... }: {
  options = {
    flakeURI = lib.mkOption {
      type = lib.types.str;
      default = "github:jojolabs/system#joris@linux";
    };
  };

  config = {
    system.autoUpgrade = {
      enable = true;
      flags = ["--update-input" "nixpkgs" "--no-write-lock-file"];
      flake = config.flakeURI;
      dates = "hourly";
      allowReboot = true;
      randomizedDelaySec = "45min";
      rebootWindow = { lower = "01:00"; upper = "05:00"; };
    };
  };
}