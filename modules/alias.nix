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
    user = mkOption {
      description = "Primary user configuration";
      type = types.attrs;
      default = {};
    };

    hm = mkOption {
      type = types.attrs;
      default = {};
    };

    flakeURI = mkOption {
      type = types.str;
      default = "github:jojolabs/system#joris@linux";
    };
  };


  config = {
    # hm -> home-manager.users.<primary user>
    home-manager.users.${config.user.name} = mkAliasDefinitions options.hm;

    # user -> users.users.<primary user>
    users.users.${config.user.name} = mkAliasDefinitions options.user;
  };
}
