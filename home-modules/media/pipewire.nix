{ pkgs, ... }:

{
  services.easyeffects.enable = true;

  home.packages = [
    pkgs.pwvucontrol
  ];

  custom.persistence.directories = [
    ".config/easyeffects"
    ".local/state/wireplumber"
  ];
}
