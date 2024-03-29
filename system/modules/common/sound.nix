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

  environment.systemPackages = with pkgs; [
    qpwgraph
    (aliasToPackage {
      helvum = "qpwgraph";
    })
  ];
}
