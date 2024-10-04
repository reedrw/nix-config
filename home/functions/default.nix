{
  # simpleHMService :: String -> String -> AttrSet
  ########################################
  # Given a name and a start command, return a simple service definition
  # to be used with home-manager's `system.user.services` option.
  # Ex.
  # simpleHMService "foo" "bar"
  #
  # Returns:
  # {
  #   foo = {
  #     Unit = {
  #       Description = "foo";
  #       After = [ "graphical.target" ];
  #     };
  #     Install = {
  #       WantedBy = [ "default.target" ];
  #     };
  #     Service = {
  #       ExecStart = "bar";
  #       Restart = "on-failure";
  #       RestartSec = 5;
  #       Type = "simple";
  #     };
  #   };
  # }
  lib.functions.mkSimpleService = name: ExecStart: {
    ${name} = {
      Unit = {
        Description = "${name}";
        After = [ "graphical.target" ];
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        inherit ExecStart;
        Restart = "on-failure";
        RestartSec = 5;
        Type = "simple";
      };
    };
  };
}
