{ ... }:

{
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
        extraConfig = ''
          user-authority-in-system-dir = true
        '';
      };
      session = [
        {
          manage = "desktop";
          name = "xsession";
          start = ''exec $HOME/.local/share/X11/xsession'';
        }
      ];
    };
  };
}
