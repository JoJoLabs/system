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

  systemd.services.inception = {
    description = "Self-bootstrap a NixOS installation";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "polkit.service" ];
    path = [ "/run/current-system/sw/" ];
    script = with pkgs; ''
      sleep 15
      ${nix}/bin/nix --experimental-features "nix-command flakes" run github:nix-community/disko -- --mode disko ${toString self}/modules/disko/default.nix
      mkdir -p /mnt/etc/nixos/   
      ${config.system.build.nixos-install}/bin/nixos-install -j 4 --flake github:JoJoLabs/system#joris@linux --no-root-passwd
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
