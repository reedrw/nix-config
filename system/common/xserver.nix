{ inputs, outputs, ... }:

{
  imports = [
    inputs.home-manager.nixosModules.home-manager
  ];
  programs.dconf.enable = true;
  services.xserver = {
    enable = true;
    displayManager = {
      autoLogin = {
        enable = true;
        user = "reed";
      };
      lightdm = {
        enable = true;
        greeter.enable = false;
      };
      session = [
        {
          manage = "desktop";
          name = "xsession";
          start = ''exec $HOME/.xsession'';
        }
      ];
    };
  };
  # Dark mode when running apps in sudo
  home-manager.extraSpecialArgs = { inherit inputs outputs; };
  home-manager.users.root = {
    home = {
      username = "root";
      homeDirectory = "/root";
      stateVersion = "22.05";
    };
    imports = [ ../../modules/styling ];
  };
}
