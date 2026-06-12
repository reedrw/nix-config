{ config, ... }:

let
  colors = config.lib.stylix.colors;
in
{
  services.swaync = {
    enable = true;

    settings = {
      positionX = "right";
      positionY = "top";
      notification-window-width = 375;
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
        font-size: 10pt;
        font-weight: bold;
      }

      notificationwindow, blankwindow {
        background: transparent;
      }

      .floating-notifications {
        background: transparent;
      }

      /* 30px padding on all sides so 20px shadow blur has room to render */
      .floating-notifications .notification-row .notification-background {
        padding: 30px;
      }

      .floating-notifications .notification-row .notification-background .notification {
        background: #${base00};
        border: none;
        border-radius: 10px;
        padding: 0;
        color: #${base05};
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.6);
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action {
        padding: 20px;
        background: transparent;
        border: none;
        border-radius: 10px;
        color: #${base05};
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action:hover {
        background: #${base01};
      }

      .floating-notifications .notification-row .notification-background .notification .notification-default-action .notification-content .image {
        -gtk-icon-size: 48px;
        margin: 0 14px 0 0;
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
        min-width: 20px;
        min-height: 20px;
        margin: 6px 6px 0 0;
      }

      .close-button:hover {
        background: #${base02};
        border: none;
      }
    '';
  };
}
