{
  sound.enable = true;

  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };

    pulse.enable = true;
    jack.enable = true;
    extraConfig.pipewire = {
      "99-playback-96khz" = {
        "context.properties" = {
          "default.clock.rate" = 192000;
          "default.clock.allowed-rates" = [ 44100 48000 88200 96000 176400 192000 ];
          "default.clock.quantum" = 352;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 2048;
          "default.clock.quantum-limit" = 8192;
        };
      };
    };
  };

  # environment.systemPackages = with pkgs; [
  #   qpwgraph
  #   (aliasToPackage {
  #     helvum = "qpwgraph";
  #   })
  # ];
}
