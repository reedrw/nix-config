{ config, lib, pkgs, ... }:

let

  sources  = import ./nix/sources.nix;

  suda-vim = pkgs.vimUtils.buildVimPlugin {
    name = "suda-vim";
    src = with sources.suda-vim;
    pkgs.fetchFromGitHub {
      owner = owner;
      repo = repo;
      rev = rev;
      sha256 = sha256;
    };
  };

  vim-polyglot = pkgs.vimUtils.buildVimPlugin {
    name = "vim-polyglot";
    src = with sources.vim-polyglot;
    pkgs.fetchFromGitHub {
      owner = owner;
      repo = repo;
      rev = rev;
      sha256 = sha256;
    };
  };

in
{

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      base16-vim
      gitgutter
      nerdtree
      suda-vim
      tabular
      vim-airline
      vim-airline-themes
      vim-polyglot
    ];
    extraConfig = with config.lib.base16;''
      if !exists('g:airline_symbols')
        let g:airline_symbols = {}
      endif

      let g:airline_symbols.maxlinenr = ' ln'
      let g:airline_symbols.branch = '⭠'

      let g:airline#extensions#tabline#enabled = 1
      let g:airline#extensions#tabline#formatter = 'unique_tail'
      let g:airline#extensions#tabline#show_tabs = 0

      let g:airline_mode_map = {
        \ '__'     : ' - ',
        \ 'c'      : ' C ',
        \ 'i'      : ' I ',
        \ 'ic'     : ' I ',
        \ 'ix'     : ' I ',
        \ 'n'      : ' N ',
        \ 'multi'  : ' M ',
        \ 'ni'     : ' N ',
        \ 'no'     : ' N ',
        \ 'R'      : ' R ',
        \ 'Rv'     : ' R ',
        \ 's'      : ' S ',
        \ 'S'      : ' S ',
        \ ''     : ' S ',
        \ 'v'      : ' V ',
        \ 'V'      : 'V-L',
        \ ''     : 'V-B',
      \}

      let g:suda_smart_edit = 1
      let g:suda#prefix = 'sudo://'

      source ${base16template "vim"}
      let base16colorspace=256
      syntax on
      set t_Co=256
      set title
      set number
      set numberwidth=5
      set cursorline

      function! s:ModeCheck(id)
        let vmode = mode() =~# '[vV�]'
        if vmode && !&rnu
          set relativenumber
        elseif !vmode && &rnu
          set norelativenumber
        endif
      endfunction
      call timer_start(100, function('s:ModeCheck'), {'repeat': -1})

      set hidden
      set ttimeoutlen=50
      set updatetime=40
      set tabstop=2
      set expandtab
      set autoindent
      set shiftwidth=2
      set mouse=a
      set noshowmode
      set nohlsearch
      command -nargs=* Hm !home-manager <args>
      highlight Comment cterm=italic gui=italic
      vnoremap <C-c> "*y
      vnoremap <C-x> "*d
      cnoremap <Up> <C-p>
      cnoremap <Down> <C-n>
      nnoremap hms :Hm switch
      nnoremap hmb :Hm build
    '';
  };
}

