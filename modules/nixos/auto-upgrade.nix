{ config, lib, ... }: {
  system.autoUpgrade = {
    enable = true;
    flags = ["--update-input" "nixpkgs" "--no-write-lock-file"];
    flake = config.flakeURI;
    dates = "hourly";
    allowReboot = true;
    randomizedDelaySec = "45min";
    rebootWindow = { lower = "01:00"; upper = "05:00"; };
  };
}