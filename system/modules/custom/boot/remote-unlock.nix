{ config, lib, ... }:
let
  cfg = config.custom.boot.remote-unlock;
in
{
  options.custom.boot.remote-unlock = {
    enable = lib.mkEnableOption "Enable remote unlock";
    default = lib.mkEnableOption "Should be enabled by default";
  };

  config = lib.mkIf cfg.enable {
    # Remote decrypt via phone shortcut
    boot.initrd = {
      availableKernelModules = [ "alx" "r8169" ];
      network = {
        enable = lib.mkDefault cfg.default;
        ssh = {
          enable = true;
          port = 2222;
          authorizedKeys = [
            "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAjDgwhUiKpmpjx/yAz8SMC1bo7bS7LiZ+9LumJfHufv Shortcuts on iPhone 13 mini"
          ];
          # sudo ssh-keygen -t ed25519 -N "" -f /persist/secrets/initrd/ssh_host_ed25519_key
          # sudo ssh-keygen -t rsa -N "" -f /persist/secrets/initrd/ssh_host_rsa_key
          hostKeys = [ "${config.custom.persistDir}/secrets/initrd/ssh_host_rsa_key" "${config.custom.persistDir}/secrets/initrd/ssh_host_ed25519_key" ];
        };
      };
    };

    specialisation = if cfg.default then {
      "no-initrd-networking".configuration = {
        boot = {
          loader.grub.configurationName = "No initrd networking";
          initrd.network.enable = false;
        };
      };
    } else {
      "initrd-networking".configuration = {
        boot = {
          loader.grub.configurationName = "Initrd networking";
          initrd.network.enable = true;
        };
      };
    };
  };
}
