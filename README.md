# nix-config

**My NixOS [home-manager](https://github.com/rycee/home-manager) config files**

[![Build and populate cache](https://github.com/reedrw/nix-config/workflows/Build%20and%20populate%20cache/badge.svg)](https://github.com/reedrw/nix-config/actions?query=workflow%3A%22Build+and+populate+cache%22) [![Cachix Cache](https://img.shields.io/badge/cachix-reedrw-blue.svg)](https://reedrw.cachix.org)

## Screenshot
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
