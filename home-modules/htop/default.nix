{
  programs.htop = {
    enable = true;
    settings = {
      tree_view = 1;
      show_program_path = 0;
      hide_kernel_threads = 1;
      hide_userland_threads = 1;
      highlight_base_name = 1;
    };
  };
}
