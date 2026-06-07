{ pkgs, ... }:

{
  services.pipewire = {
    enable = true;
    alsa = {
      enable = true;
      support32Bit = true;
    };

    systemWide = true;

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
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-priority-defaults.conf" ''
        wireplumber.settings = {
          node.restore-default-targets = false
        }
      '')
      (pkgs.writeTextDir "share/wireplumber/wireplumber.conf.d/51-disable-suspension.conf" ''
        monitor.alsa.rules = [
          {
            matches = [
              { node.name = "~alsa_input.*" },
              { node.name = "~alsa_output.*" }
            ]
            actions = {
              update-props = {
                session.suspend-timeout-seconds = 0
              }
            }
          }
        ]
        monitor.bluez.rules = [
          {
            matches = [
              { node.name = "~bluez_input.*" },
              { node.name = "~bluez_output.*" }
            ]
            actions = {
              update-props = {
                session.suspend-timeout-seconds = 0
                priority.session = 3000
              }
            }
          }
        ]
      '')
    ];
  };

  environment.systemPackages = with pkgs; [
    qpwgraph
    (aliasToPackage {
      helvum = "qpwgraph";
    })
  ];

  custom.persistence.directories = [
    "/var/lib/pipewire"
  ];
}
