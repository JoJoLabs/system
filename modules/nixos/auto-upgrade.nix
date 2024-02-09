{ flake_uri ? "github:jojolabs/system#joris@linux"} : {
  system.autoUpgrade = {
    enable = true;
    flags = ["--update-input" "nixpkgs"];
    flake = flake_uri;
    dates = "hourly";
    allowReboot = true;
    randomizedDelaySec = "45min";
    rebootWindow = { lower = "01:00"; upper = "05:00"; };
  };
}