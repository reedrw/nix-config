# nix-config
My NixOS [home-manager](https://github.com/rycee/home-manager) config files
![screenshot](screenshot.png)

## Install

```sh
cd ~/.config
git clone https://github.com/reedrw/nix-config nixpkgs
cd nixpkgs
cachix use reedrw # Optional
nix-shell
home-manager switch
```
