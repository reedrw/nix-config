{ config, lib, pkgs, ... }:

{
  home = {
    packages = with pkgs; [ weechat ];
    file = {
      ".weechat/weechat.conf".source = ./weechat.conf;
      ".weechat/buflist.conf".source = ./buflist.conf;
      ".weechat/xfer.conf".source = ./xfer.conf;
    };
  };
}
