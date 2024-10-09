{ lib, pkgs, ... }:
let
  myLorri = pkgs.lorri;
in
{
  home.packages = [
    myLorri
  ];

  systemd.user.services = {
    lorri = {
      Unit = {
        Description = "lorri build daemon";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = with pkgs; {
        ExecStart = "${myLorri}/bin/lorri daemon";
        Restart = "on-failure";
        Environment = let
          path =
            lib.strings.makeSearchPath "bin" [ pkgs.nix gitMinimal gnutar gzip ];
        in [ "PATH=${path}" ];
      };
    };

    lorri-notify = {
      Unit = {
        Description = "lorri build notifications";
        After = "lorri.service";
        Requires = "lorri.service";
      };

      Install = {
        WantedBy = [ "default.target" ];
      };

      Service = {
        ExecStart = let
          jqFile = ''
            (
              (.Started?   | values | "Build starting in \(.nix_file)"),
              (.Completed? | values | "Build complete in \(.nix_file)"),
              (.Failure?   | values | "Build failed in \(.nix_file)")
            )
          '';

          notifyScript = pkgs.writeShellScript "lorri-notify" ''
            lorri internal stream-events --kind live \
              | jq --unbuffered '${jqFile}' \
              | xargs -n 1 notify-send "Lorri Build"
          '';
        in toString notifyScript;
        Restart = "on-failure";
        Environment = let
          path = lib.strings.makeSearchPath "bin"
            (with pkgs; [ bash jq findutils libnotify myLorri ]);
        in "PATH=${path}";
      };
    };
  };
}
