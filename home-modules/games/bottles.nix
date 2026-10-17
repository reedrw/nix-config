{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (unstable.bottles.override {
      removeWarningPopup = true;
      extraPkgs = _: [
        pkgs.linuwux-runtime
      ];
    })
    ludusavi
  ];

  custom.persistence.directories = [
    ".local/share/bottles"
    ".config/ludusavi"
  ];
}
