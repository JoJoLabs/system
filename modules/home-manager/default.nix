{
  config,
  pkgs,
  ...
}: {
  nixpkgs.config = {
    allowUnfree = true;
  };

  home = let
    NODE_GLOBAL = "${config.home.homeDirectory}/.node-packages";
  in {
    # This value determines the Home Manager release that your
    # configuration is compatible with. This helps avoid breakage
    # when a new Home Manager release introduces backwards
    # incompatible changes.
    #
    # You can update Home Manager without changing this value. See
    # the Home Manager release notes for a list of state version
    # changes in each release.
    stateVersion = "22.05";
    sessionVariables = {
      GPG_TTY = "/dev/ttys000";
      CLICOLOR = 1;
      LSCOLORS = "ExFxBxDxCxegedabagacad";
    };
    sessionPath = [
      "${NODE_GLOBAL}/bin"
      "${config.home.homeDirectory}/.rd/bin"
      "${config.home.homeDirectory}/.local/bin"
    ];

    # define package definitions for current user environment
    packages = with pkgs; [
      # age
      coreutils-full
      curl
      diffutils
      fd
      findutils
      kubectl
      kubectx
      kubernetes-helm
      kustomize
      neofetch
      nix
      nixfmt
      nixpkgs-fmt
      rclone
      ruff
      rsync
      shellcheck
      tree
      trivy
      yq-go
    ];
  };

  programs = {
    home-manager = {
      enable = true;
    };
    go.enable = true;
    gpg.enable = true;
    htop.enable = true;
    jq.enable = true;
    java = {
      enable = true;
      package = pkgs.jdk21;
    };
    k9s.enable = true;
    lazygit.enable = true;
    less.enable = true;
    man.enable = true;
    nix-index.enable = true;
    pandoc.enable = true;
    ripgrep.enable = true;
    starship.enable = true;
    yt-dlp.enable = true;
    zoxide.enable = true;
  };
}
