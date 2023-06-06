{ inputs, ... }:

{
  imports = [
    inputs.impermanence.nixosModules.home-manager.impermanence
  ];

  home.persistence."/persist/reed" = {
    allowOther = true;
    directories = [
      ".cache/lorri"
      ".cache/mesa_shader_cache"
      ".cache/mozilla"
      ".cache/mpv"
      ".cache/nix"
      ".cache/pre-commit"
      ".cache/ranger"

      ".config/BetterDiscord"
      ".config/Bitwarden CLI"
      ".config/Bitwarden"
      ".config/Mullvad VPN"
      ".config/cachix"
      ".config/coc"
      ".config/dconf"
      ".config/discord"
      ".config/easyeffects"
      ".config/gh"
      ".config/htop"
      ".config/nixpkgs"
      ".config/obs-studio"

      ".local/share/PrismLauncher"
      ".local/share/Steam"
      ".local/share/TelegramDesktop"
      ".local/share/anime-game-launcher"
      ".local/share/direnv"
      # ".local/share/honkers-railway-launcher"
      ".local/share/ranger"

      ".local/state/wireplumber"

      ".mozilla/firefox"

      ".ssh"
    ];
    files = [
      ".cache/rofi-2.sshcache"
      ".cache/rofi-3.runcache"
      ".cache/rofi3.druncache"
      ".gitconfig"
      ".zsh_history"

      # symlinks for xdg dirs
      "downloads"
      "files"
      "games"
      "images"
      "music"
      "persist"
      "videos"
    ];
  };
}
