{ osConfig, ... }:

{
  nix = {
    package = osConfig.nix.package;
    settings.use-xdg-base-directories = true;
  };
}
