{
  config,
  pkgs,
  lib,
  ...
}: {
  # bundles essential nixos modules
  imports = [../common.nix ./auto-upgrade.nix ./services];

  environment.systemPackages = with pkgs; [vscode firefox];

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users = {
    defaultUserShell = pkgs.zsh;
    mutableUsers = false;
    users = {
      "${config.user.name}" = {
        isNormalUser = true;
        extraGroups = ["wheel" "networkmanager"]; # Enable ‘sudo’ for the user.
        hashedPassword = "$y$j9T$rVX/VI1C0nwrX8LSSOX2A.$eI2I8JWyLNKS0Z1FeH.MrcAsG8fwRmIM40A9CWvQuj4";
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIG/9Su+30SG1ajlNedNtTwrO2Pmmf/VdJv1uPc3Hbx4l joris@jojolabs.com"
        ];
      };
    };
  };

  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = lib.mkDefault true;

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = lib.mkDefault true;
  boot.loader.grub.efiSupport = lib.mkDefault true;
  boot.loader.grub.efiInstallAsRemovable = lib.mkDefault true;
  # Define on which hard drive you want to install Grub.
  ### Managed by disko ###
  # boot.loader.grub.device = "/dev/vda"; # or "nodev" for efi only
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = lib.mkDefault true;



  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = pkgs.jetbrains-mono;
    keyMap = "us";
  };

  # Set your time zone.
  time.timeZone = "PST";
  services.geoclue2.enable = true;
  services.localtimed.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
    # pinentryFlavor = "gnome3";
  };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
