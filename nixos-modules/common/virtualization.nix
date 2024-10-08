{
  boot.kernelModules = [ "kvm-intel" ];

  virtualisation.docker = {
    enable = true;
    daemon.settings = {
      dns = [ "1.1.1.1" "8.8.8.8" "10.64.0.1" ];
      storage-driver = "overlay2";
    };
  };

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
}
