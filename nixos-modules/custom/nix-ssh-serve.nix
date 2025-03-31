{ lib, config, ... }:

{
  options.custom.nix-ssh-serve = {
    enable = lib.mkEnableOption "Enable nix-ssh-serve";
    keys = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "List of ssh keys to allow";
    };
    secretKeyFiles = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = lib.throw "You must specify at least one secret key file";
      description = "Paths to secret key files";
    };
  };

  config = lib.mkIf config.custom.nix-ssh-serve.enable {
    nix = {
      extraOptions = ''
        secret-key-files = ${builtins.concatStringsSep " " config.custom.nix-ssh-serve.secretKeyFiles}
      '';
      envVars.SSH_AUTH_SOCK = "/run/user/1000/gnupg/S.gpg-agent.ssh";
      sshServe = {
        enable = true;
        keys = config.custom.nix-ssh-serve.keys;
      };
    };
  };

  # nix = {
  #   extraOptions = ''
  #     secret-key-files = ${config.custom.persistDir}/secrets/nix-store/nix-store-secret-key.pem
  #   '';
  #   envVars.SSH_AUTH_SOCK = "/run/user/1000/gnupg/S.gpg-agent.ssh";
  #   sshServe = {
  #     enable = true;
  #     keys = [
  #       "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIP4QB7g+vkkytelSG2Wcibmxn7b3ZhnezFjpppD/MCWW root@nixos-t480"
  #     ];
  #   };
  # };
}
