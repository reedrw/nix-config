{
  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = [ "1.1.1.1" "8.8.8.8" "10.64.0.1" ];
      storage-driver = "overlay2";
    };
  };
}
