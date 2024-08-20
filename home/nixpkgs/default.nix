{ osConfig, lib, ... }:

{
  nix = {
    package = lib.mkDefault osConfig.nix.package;
    settings.use-xdg-base-directories = true;
  };
}
