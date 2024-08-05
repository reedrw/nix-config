{ ... }:
let
  browser = "firefox.desktop";
  media-player = "mpv.desktop";
  image-viewer = "org.gnome.Loupe.desktop";
  rich-text-editor = "libreoffice.desktop";
  editor = "nvim.desktop";
in
{
  xdg.mimeApps.defaultApplications = {
    "application/pdf" = "org.pwmt.zathura.desktop";
    "application/doc" = rich-text-editor;
    "application/docx" = rich-text-editor;
    "application/flac" = media-player;
    "application/wav" = media-player;
    "application/ogg" = media-player;
    "application/mp3" = media-player;
    "image/gif" = image-viewer;
    "image/png" = image-viewer;
    "image/jpg" = image-viewer;
    "image/jpeg" = image-viewer;
    "image/webp" = image-viewer;
    "video/mkv" = media-player;
    "video/mov" = media-player;
    "video/mp4" = media-player;
    "video/webm" = media-player;
    "text/hs" = editor;
    "text/html" = browser;
    "text/js" = editor;
    "text/json" = editor;
    "text/nix" = editor;
    "text/rs" = editor;
    "text/sh" = editor;
    "text/yaml" = editor;
    "text/yml" = editor;
  };
}
