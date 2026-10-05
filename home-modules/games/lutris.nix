{ pkgs, ... }:

{
  home.packages = with pkgs; [
    (lutris.override {
      extraPkgs = _: [
        pkgs.linuwux-runtime
      ];
    })
  ];

  custom.persistence.directories = [
    ".local/share/lutris"
    ".local/share/umu"
  ];
}
