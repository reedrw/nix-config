{
  boot.kernelModules = [ "kvm-intel" ];

  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;
}
