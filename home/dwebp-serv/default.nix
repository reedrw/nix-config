{ pkgs, ... }:
let
  dwebp-serv = pkgs.writeNixShellScript "dwebp-serv" (builtins.readFile ./dwebp-serv.sh);
in
{
  systemd.user.services = with pkgs; mkSimpleHMService "dwebp-serv" "${binPath dwebp-serv}";
}
