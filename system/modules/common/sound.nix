{ pkgs, ... }:

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
  };

  environment.etc."pipewire/pipewire.conf.d/99-playback-96khz.conf".text = ''
    context.properties = {
      default.clock.rate = 96000;
      default.clock.allowed-rates = [ 44100 48000 88200 96000 176400 192000 ];
    }
  '';

  environment.systemPackages = with pkgs; [
    qpwgraph
    (aliasToPackage {
      helvum = "qpwgraph";
    })
  ];
}
