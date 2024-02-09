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

  sops.defaultSopsFile = "${toString self}/secrets/sops.yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
  sops.secrets.github_private_key = {};

  systemd.services.inception = {
    description = "Self-bootstrap a NixOS installation";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "polkit.service" ];
    path = [ "/run/current-system/sw/" ];
    script = with pkgs; ''
      sleep 5
      mkdir -p /mnt/etc/nixos/
      eval "$(ssh-agent -s)"
      ssh-add ${config.sops.secrets.github_private_key.path}      
      ${config.system.build.nixos-install}/bin/nixos-install -j 4 --flake git@github.com:JoJoLabs/system.git#joris@x86_64-linux
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
