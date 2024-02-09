{
  config,
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [vscode firefox];

  networking.hostName = "nixos"; # Define your hostname.
  networking.networkmanager.enable = true;

  # Use the GRUB 2 boot loader.
  boot.loader.grub.enable = lib.mkDefault true;
  # Define on which hard drive you want to install Grub.
  boot.loader.grub.device = lib.mkDefault "/dev/vda"; # or "nodev" for efi only
  # boot.loader.grub.efiSupport = true;
  # boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.efiSysMountPoint = "/boot/efi";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  # networking.useDHCP = true;

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  # console = {
  #   font = pkgs.jetbrains-mono;
  #   keyMap = "us";
  # };

  # Set your time zone.
  # time.timeZone = "EST";
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

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.09"; # Did you read the comment?
}
