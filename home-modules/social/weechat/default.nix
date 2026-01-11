{ pkgs, ... }:

{
  home.packages = [ pkgs.weechat ];

  xdg.configFile = {
    "weechat/weechat.conf".source = ./weechat.conf;
    "weechat/buflist.conf".source = ./buflist.conf;
    "weechat/xfer.conf".source = ./xfer.conf;
  };

  custom.persistence = {
    directories = [
      ".local/share/weechat"
    ];
    files = [
      ".config/weechat/irc.conf"
    ];
  };
}
