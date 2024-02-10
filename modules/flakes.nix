{
  config,
  lib,
  options,
  ...
}:
# module used courtesy of @i077 - https://github.com/i077/system/
let
  inherit (lib) mkAliasDefinitions mkOption types;
in {
  # Define some aliases for ease of use
  options = {
    flakeURI = mkOption {
      type = types.str;
      default = "github:jojolabs/system#joris@linux";
    };
  };
}
