{ pkgs, ... }:

{
  users.users.root.packages = with pkgs; [
    git
    neovim
    ranger
  ];
}
