{ ... }:
let
  json = (builtins.fromJSON (builtins.readFile ./persist.json));
in
{
  programs.fuse.userAllowOther = true;
  environment.persistence."/persist" = {
    hideMounts = true;
    directories = [
      "/etc/mullvad-vpn"
      "/etc/nixos"
      "/etc/ssh"

      "/var/db/sudo"

      "/var/lib/NetworkManager"
      "/var/lib/blueman"
      "/var/lib/bluetooth"
      "/var/lib/deluge"
      "/var/lib/docker"
      "/var/lib/jellyfin"
      "/var/lib/libvirt"
      "/var/lib/systemd"
      "/var/lib/tailscale"


      "/home/reed/.cache/lorri"
      "/home/reed/.cache/mesa_shader_cache"
      "/home/reed/.cache/mozilla"
      "/home/reed/.cache/mpv"
      "/home/reed/.cache/nix"
      "/home/reed/.cache/pre-commit"
      "/home/reed/.cache/ranger"


      "/home/reed/.config/Bitwarden CLI"
      "/home/reed/.config/Bitwarden"
      "/home/reed/.config/BetterDiscord"
      "/home/reed/.config/Mullvad VPN"
      "/home/reed/.config/cachix"
      "/home/reed/.config/coc"
      "/home/reed/.config/dconf"
      "/home/reed/.config/discord"
      "/home/reed/.config/easyeffects"
      "/home/reed/.config/gh"
      "/home/reed/.config/htop"
      "/home/reed/.config/nixpkgs"
      "/home/reed/.config/obs-studio"

      "/home/reed/.local/share/PrismLauncher"
      "/home/reed/.local/share/Steam"
      "/home/reed/.local/share/TelegramDesktop"
      "/home/reed/.local/share/anime-game-launcher"
      "/home/reed/.local/share/direnv"
      # "/home/reed/.local/share/honkers-railway-launcher"
      "/home/reed/.local/share/ranger"

      "/home/reed/.local/state/wireplumber"

      "/home/reed/.mozilla/firefox"

      "/home/reed/.ssh"
    ] ++ json.directories;
  };
}
