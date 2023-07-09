{ inputs, ... }:

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
}
