{ config, osConfig, ... }:

let
  colors = config.lib.stylix.colors;
  inherit (osConfig.custom.display) dp;
in
{
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      notification-window-width = dp 375;
      timeout          = 4;
      timeout-low      = 4;
      timeout-critical = 4;
      notification-grouping = false;
      relative-timestamps   = false;
      hide-on-action        = true;

      widgets = [ "title" "notifications" ];

      widget-config.title = {
        text             = "Notifications";
        clear-all-button = true;
        button-text      = "Clear All";
      };
    };

    style = with colors; ''
      * {
        font-family: "FantasqueSansMNerdFont", "Kochi Gothic";
        font-size: ${toString (dp 10)}pt;
        font-weight: bold;
      }

      notificationwindow, blankwindow {
        background: transparent;
      }

      .floating-notifications {
        background: transparent;
      }

      /* padding on all sides leaves room for the shadow blur to render */
      .floating-notifications .notification-row .notification-background {
        padding: 2.25em;
      }

      .floating-notifications .notification-row .notification-background .notification {
        background: #${base00};
        border: none;
        border-radius: 0.75em;
        padding: 0;
        color: #${base05};
        box-shadow: 0 0.3em 1.5em rgba(0, 0, 0, 0.6);
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action {
        padding: 1.5em;
        background: transparent;
        border: none;
        border-radius: 0.75em;
        color: #${base05};
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action:hover {
        background: #${base01};
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action .notification-content .image {
        -gtk-icon-size: 3.6em;
        margin: 0 1.05em 0 0;
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .summary {
        color: #${base05};
        font-weight: bold;
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action .notification-content .text-box .body {
        color: #${base05};
      }

      .close-button {
        background: #${base01};
        color: #${base05};
        border: none;
        min-width: 1.5em;
        min-height: 1.5em;
        margin: 0.45em 0.45em 0 0;
      }

      .close-button:hover {
        background: #${base02};
        border: none;
      }
    '';
  };
}
