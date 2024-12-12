{ pkgs, ... }:

{
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

    # https://github.com/wwmm/easyeffects/issues/2521#issuecomment-2134144237
    wireplumber.configPackages = [
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-disable-suspension.conf" ''
        monitor.alsa.rules = [
          {
            matches = [
              {
                # Matches all sources
                node.name = "~alsa_input.*"
              },
              {
                # Matches all sinks
                node.name = "~alsa_output.*"
              }
            ]
            actions = {
              update-props = {
                session.suspend-timeout-seconds = 0
              }
            }
          }
        ]
        # bluetooth devices
        monitor.bluez.rules = [
          {
            matches = [
              {
                # Matches all sources
                node.name = "~bluez_input.*"
              },
              {
                # Matches all sinks
                node.name = "~bluez_output.*"
              }
            ]
            actions = {
              update-props = {
                session.suspend-timeout-seconds = 0
              }
            }
          }
        ]
      '')
    ];
  };

  # environment.systemPackages = with pkgs; [
  #   qpwgraph
  #   (aliasToPackage {
  #     helvum = "qpwgraph";
  #   })
  # ];
}
