inputs:
self: pkgs:
let
  lib = pkgs.lib;
in
{
  inherit (inputs) get-flake;

  nix = inputs.lix.packages.x86_64-linux.nix.overrideAttrs (old: {
    doCheck = false;
    patches = [ ./nix.patch ];
  });

  nixos-option = pkgs.nixos-option.override {
    nix = pkgs.nix;
  };

  nil = inputs.nil.packages.x86_64-linux.nil;

  lockProgram = self.i3lock-fancy.override {
    screenshotCommand = "${lib.getExe pkgs.maim} -u";
  };

  myNodeEnv = pkgs.callPackage ./node/node-env.nix {};

  myNodePackages = pkgs.callPackage ./node/node-packages.nix {
    nodeEnv = self.myNodeEnv;
  };
  # nodejs = pkgs.nodejs.overrideAttrs (old: {
  #   postInstall = old.postInstall + ''
  #     cp -rL ${globalNodePackages}/lib/node_modules $out/lib/node_modules
  #   '';
  # });
  myNodejs = let
    globalNodePackages = pkgs.symlinkJoin {
      name = "node-packages";
      paths = builtins.attrValues self.myNodePackages |> lib.filter lib.isDerivation;
    };
  in pkgs.runCommandNoCC "nodejs" {
    name = "nodejs-with-packages";
    buildInputs = [ pkgs.nodejs ];
    # meta = pkgs.nodejs.meta;
    inherit (pkgs.nodejs) meta version src;
    python = pkgs.python3;
  } ''
    cp -r ${pkgs.nodejs} $out
    chmod -R u+w $out
    cp -rL ${globalNodePackages}/lib/node_modules/* $out/lib/node_modules/
    chmod -R u+w $out
    find $out -type f -exec \
      sed -i "s|${lib.getExe pkgs.nodejs}|$out/bin/node|g" {} +;
  '';

  # wrapNeovimUnstable = pkgs.wrapNeovimUnstable {
  #   nodejs = self.myNodejs;
  # };
  wrapNeovimUnstable = pkgs.callPackage "${inputs.nixpkgs}/pkgs/applications/editors/neovim/wrapper.nix" {
    nodejs = self.myNodejs;
    # inherit (pkgs.neovim-unwrapped) src meta version;
  };
}
