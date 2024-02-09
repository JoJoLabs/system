{
  config,
  self,
  pkgs,
  sops,
  ...
}: {
  users.mutableUsers = false;
  fileSystems = [
    { mountPoint = "/"; fsType = "ext4"; label = "root"; }
  ];

  # sops.defaultSopsFile = "${toString self}/secrets/sops.yaml";
  # sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  # sops.secrets.github_private_key = {};

  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
  ];

  tools = lib.makeBinPath (
    with pkgs; [
      config.system.build.nixos-enter
      config.system.build.nixos-install
      nix
      parted
    ]
  );

  systemd.services.inception = {
    description = "Self-bootstrap a NixOS installation";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "polkit.service" ];
    path = [ "${tools}" ];
    script = with pkgs; ''
      sleep 60
      ${config.system.build.nix}/bin/nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ${toString self}/modules/disko/disko-config.nix
      mkdir -p /mnt/etc/nixos/   
      ${config.system.build.nixos-install}/bin/nixos-install --experimental-features "nix-command flakes" -j 4 --flake git+ssh://git@github.com/JoJoLabs/system#joris@x86_64-linux --no-root-passwd
      ${systemd}/bin/shutdown -r now
    '';
    environment = config.nix.envVars // {
      inherit (config.environment.sessionVariables) NIX_PATH;
      HOME = "/root";
    };
    serviceConfig = {
      Type = "oneshot";
    };
};
}
