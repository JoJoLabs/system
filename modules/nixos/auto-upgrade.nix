{ ... }: {

  options = {
    flakeURI = mkOption {
      type = types.string;
      default = "github:jojolabs/system#joris@linux";
    };
  };

  config = {
    system.autoUpgrade = {
      enable = true;
      flags = ["--update-input" "nixpkgs"];
      flake = config.flakeURI;
      dates = "hourly";
      allowReboot = true;
      randomizedDelaySec = "45min";
      rebootWindow = { lower = "01:00"; upper = "05:00"; };
    };
  };
}