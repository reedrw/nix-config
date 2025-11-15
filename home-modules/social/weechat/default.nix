{ pkgs, ... }:

{
  home.packages = with pkgs; [ weechat ];
  xdg.configFile = {
    "weechat/weechat.conf".source = ./weechat.conf;
    "weechat/buflist.conf".source = ./buflist.conf;
    "weechat/xfer.conf".source = ./xfer.conf;
  };
}
