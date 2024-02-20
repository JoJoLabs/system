{
  description = "nix system configurations";

  nixConfig = {};

  inputs = {
    # package repos
    stable.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs.url = "github:jorisbolsens/nixpkgs/patch-4";
    nixos-unstable.url = "github:jorisbolsens/nixpkgs/patch-4";
    devenv.url = "github:cachix/devenv/latest";

    # system management
    nixos-hardware.url = "github:nixos/nixos-hardware";
    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:Mic92/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # shell stuff
    flake-utils.url = "github:numtide/flake-utils";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = {
    self,
    darwin,
    devenv,
    flake-utils,
    home-manager,
    nixos-generators,
    disko,
    sops-nix,
    ...
  } @ inputs: let
    inherit (flake-utils.lib) eachSystemMap;

    isDarwin = system: (builtins.elem system inputs.nixpkgs.lib.platforms.darwin);
    homePrefix = system:
      if isDarwin system
      then "/Users"
      else "/home";
    defaultSystems = [
      # "aarch64-linux"
      "aarch64-darwin"
      "x86_64-darwin"
      "x86_64-linux"
    ];

    # generate a base darwin configuration with the
    # specified hostname, overlays, and any extraModules applied
    mkDarwinConfig = {
      system ? "aarch64-darwin",
      nixpkgs ? inputs.nixpkgs,
      baseModules ? [
        home-manager.darwinModules.home-manager
        ./modules/darwin
      ],
      extraModules ? [],
    }:
      inputs.darwin.lib.darwinSystem {
        inherit system;
        modules = baseModules ++ extraModules;
        specialArgs = {inherit self inputs nixpkgs;};
      };

    # generate a base nixos configuration with the
    # specified overlays, hardware modules, and any extraModules applied
    mkNixosConfig = {
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixos-unstable,
      hardwareModules,
      baseModules ? [
        home-manager.nixosModules.home-manager
        ./modules/nixos
      ],
      extraModules ? [],
    }:
      nixpkgs.lib.nixosSystem {
        inherit system;
        modules = baseModules ++ hardwareModules ++ extraModules;
        specialArgs = {inherit self inputs nixpkgs;};
      };

    # generate a home-manager configuration usable on any unix system
    # with overlays and any extraModules applied
    mkHomeConfig = {
      username,
      system ? "x86_64-linux",
      nixpkgs ? inputs.nixpkgs,
      baseModules ? [
        ./modules/home-manager
        {
          home = {
            inherit username;
            homeDirectory = "${homePrefix system}/${username}";
            sessionVariables = {
              NIX_PATH = "nixpkgs=${nixpkgs}:stable=${inputs.stable}\${NIX_PATH:+:}$NIX_PATH";
            };
          };
        }
      ],
      extraModules ? [],
    }:
      inputs.home-manager.lib.homeManagerConfiguration rec {
        pkgs = import nixpkgs {
          inherit system;
          overlays = builtins.attrValues self.overlays;
        };
        extraSpecialArgs = {inherit self inputs nixpkgs;};
        modules = baseModules ++ extraModules;
      };

    mkChecks = {
      arch,
      os,
      username ? "joris",
    }: {
      "${arch}-${os}" = {
        "${username}_${os}" =
          (
            if os == "darwin"
            then self.darwinConfigurations
            else self.nixosConfigurations
          )
          ."${username}@${arch}-${os}"
          .config
          .system
          .build
          .toplevel;
        "${username}_home" =
          self.homeConfigurations."${username}@${arch}-${os}".activationPackage;
        devShell = self.devShells."${arch}-${os}".default;
      };
    };
  in {
    checks =
      {}
      // (mkChecks {
        arch = "aarch64";
        os = "darwin";
      })
      // (mkChecks {
        arch = "x86_64";
        os = "darwin";
      })
      // (mkChecks {
        arch = "aarch64";
        os = "linux";
      })
      // (mkChecks {
        arch = "x86_64";
        os = "linux";
      });

    # darwinConfigurations = {
    #   "joris@aarch64-darwin" = mkDarwinConfig {
    #     system = "aarch64-darwin";
    #     extraModules = [./profiles/personal.nix ./modules/darwin/apps.nix];
    #   };
    # };

    nixosConfigurations = {
      "joris@linux" = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          disko.nixosModules.disko
          ./modules/disko/default.nix
          ./modules/hardware/rhel-vm.nix
        ];
        extraModules = [./profiles/default.nix];
      };
      "kubemaster" = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          disko.nixosModules.disko
          ./modules/disko/default.nix
          ./modules/hardware/rhel-vm.nix
        ];
        extraModules = [
          ./modules/flakes.nix
          ./profiles/default.nix
          ./profiles/kubemaster.nix
          # ./modules/nixos/kubernetes/master.nix
          ./modules/nixos/services/auto-hostname.nix
        ];
      };
      "kubenode" = mkNixosConfig {
        system = "x86_64-linux";
        hardwareModules = [
          disko.nixosModules.disko
          ./modules/disko/default.nix
          ./modules/hardware/rhel-vm.nix
        ];
        extraModules = [
          ./modules/flakes.nix
          ./profiles/default.nix
          ./profiles/kubenode.nix
          # ./modules/nixos/kubernetes/node.nix
          ./modules/nixos/services/auto-hostname.nix
        ];
      };
    };

    packages.x86_64-linux = {
      kubemaster-installer = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        specialArgs = {inherit self inputs;};
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules/disko/default.nix
          ./modules/flakes.nix
          ./profiles/kubemaster.nix
          ./modules/nixos/installer.nix
        ];
        format = "install-iso";
      };
      kubenode-installer = nixos-generators.nixosGenerate {
        system = "x86_64-linux";
        specialArgs = {inherit self inputs;};
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./modules/disko/default.nix
          ./modules/flakes.nix
          ./profiles/kubenode.nix
          ./modules/nixos/installer.nix
        ];
        format = "install-iso";
      };
    };

    homeConfigurations = {
      "joris@x86_64-linux" = mkHomeConfig {
        username = "joris";
        system = "x86_64-linux";
        extraModules = [./profiles/home-manager/default.nix];
      };
    };

    devShells = eachSystemMap defaultSystems (system: let
      pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = builtins.attrValues self.overlays;
      };
    in {
      default = devenv.lib.mkShell {
        inherit inputs pkgs;
        modules = [
          (import ./devenv.nix)
        ];
      };
    });

    overlays = {
      channels = final: prev: {
        # expose other channels via overlays
        stable = import inputs.stable {system = prev.system;};
      };
    };
  };
}
