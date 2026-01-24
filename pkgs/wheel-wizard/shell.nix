{ pkgs ? (import ../../repo/compat.nix).legacyPackages."${builtins.currentSystem}".util.pkgsForSystem (import ../../repo/compat.nix).inputs.nixpkgs builtins.currentSystem }:

pkgs.mkShell {
  name = "update-nuget-json";
  packages = with pkgs; [
    dotnet-sdk_8
    nuget-to-json
  ];
}
