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

  # Allow `wheel` group to change colorscheme
  security.sudo.extraRules = [
    {
      groups = [ "wheel" ];
      commands = [
        {
          command = "/nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration switch";
          options = [ "NOPASSWD" ];
        }
        {
          command = "/nix/var/nix/profiles/system/bin/switch-to-configuration switch";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  environment.systemPackages = [
    (pkgs.writeShellScriptBin "toggle-theme" ''
      # get current active system configuration
      current_system=$(readlink /run/current-system)

      # get the system path for the 'light' specialisation
      light_specialisation=$(readlink /nix/var/nix/profiles/system/specialisation/light)

      # check if the current system configuration matches the 'light' specialisation
      if [ "$current_system" == "$light_specialisation" ]; then
         ${lib.getExe pkgs.libnotify} "Switching to Dark"
         sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch
      else
         ${lib.getExe pkgs.libnotify} "Switching to Light"
         sudo /nix/var/nix/profiles/system/specialisation/light/bin/switch-to-configuration switch
      fi
    '')
  ];

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
