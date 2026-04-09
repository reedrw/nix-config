{ pkgs, lib, util, inputs, ... }:
let
  # schemes is from https://github.com/tinted-theming/schemes
  schemes = (util.importFlake ./sources).inputs.schemes;
in
{
  imports = [
    inputs.stylix.nixosModules.stylix
  ];

  specialisation.light.configuration = {
    stylix = {
      enable = true;
      autoEnable = false;
      homeManagerIntegration = {
        autoImport = false;
      };
      polarity = lib.mkForce "light";
      image = lib.mkForce ./wallpaper.png;
      base16Scheme = lib.mkForce "${schemes}/base16/ayu-light.yaml";
    };
    environment.etc."nixos/specialisation".text = "light";
  };

  stylix = {
    enable = true;
    autoEnable = false;
    homeManagerIntegration = {
      autoImport = false;
    };
    polarity = "dark";
    image = ./wallpaper.png;
    base16Scheme = "${schemes}/base16/ayu-dark.yaml";
  };

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "toggle-theme" ''
      PATH="${lib.makeBinPath [ pkgs.libnotify ]}:$PATH"
      # get current active system configuration
      current_system=$(readlink /run/current-system)

      # get the system path for the 'light' specialisation
      light_specialisation=$(readlink /nix/var/nix/profiles/system/specialisation/light)

      # check if the current system configuration matches the 'light' specialisation
      if [ "$current_system" == "$light_specialisation" ]; then
         notify-send "Switching to Dark"
         systemctl start switch-to-dark
      else
         notify-send "Switching to Light"
         systemctl start switch-to-light
      fi

      systemctl restart --user authentication-agent
    '')
  ];

  systemd.services = {
    "switch-to-dark" = {
      unitConfig = {
        Description = "Switch to dark specialization";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = (pkgs.writeShellScript "switch-to-dark" ''
          /nix/var/nix/profiles/system/bin/switch-to-configuration test
          /nix/var/nix/profiles/system/bin/switch-to-configuration boot
        '').outPath;
      };
    };
    "switch-to-light" = {
      unitConfig = {
        Description = "Switch to dark specialization";
      };
      serviceConfig = {
        Type = "oneshot";
        ExecStart = (pkgs.writeShellScript "switch-to-dark" ''
          /nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration test
          /nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration boot
        '').outPath;
      };
    };
  };

  security.polkit.extraConfig = lib.mkBefore ''
    polkit.addRule(function(action, subject) {
      if (action.id.indexOf("org.freedesktop.systemd1.") == 0) {
        var allowedUnits = [
          "switch-to-light.service",
          "switch-to-dark.service"
        ];

        var unit = action.lookup("unit");

        if (allowedUnits.indexOf(unit) !== -1) {
          return polkit.Result.YES;
        }
      }
      return polkit.Result.NOT_HANDLED;
    });
  '';

  stylix.icons = {
    enable = true;
    package = pkgs.papirus-icon-theme;
    dark = "Papirus-Dark";
    light = "Papirus-Light";
  };

  stylix.fonts = {
    sansSerif = {
      package = pkgs.cantarell-fonts;
      name = "Cantarell";
    };
    sizes.applications = 10;
  };

  stylix.cursor = {
    package = pkgs.openzone-cursors;
    name = "OpenZone_Black";
    size = 24;
  };

  stylix.targets = {
    gtk.enable = true;
    qt.enable = true;
  };
}
