{ pkgs, ... }:

{
  hardware.logitech = {
    wireless = {
      enable = true;
      enableGraphical = true;
    };
  };

  services.ratbagd.enable = true;

  environment.systemPackages = with pkgs; [
    piper
  ];
}
