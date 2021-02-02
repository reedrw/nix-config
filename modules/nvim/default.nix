{ config, lib, pkgs, ... }:

{

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; let
      suda-vim = pkgs.vimUtils.buildVimPlugin {
        name = "suda-vim";
        src = pkgs.fetchFromGitHub {
          owner = "lambdalisue";
          repo = "suda.vim";
          rev = "da785547bb9aa8a497f0e0fce332d9f6a5ee5955";
          sha256 = "06vi3splalfp04prwjhlm533n227a61yh5y9h48pgfgixqqsmyi6";
        };
      };
    in
    [
      The_NERD_Commenter
      base16-vim
      gitgutter
      nerdtree
      suda-vim
      tabular
      vim-airline
      vim-airline-themes
      vim-fugitive
      vim-polyglot
    ];
    extraConfig = with config.lib.base16; let
      nivscript = pkgs.writeShellScript "nivscript" ''
        package=$(</dev/stdin)

        if type niv &> /dev/null; then
          niv=niv
        else
          niv="nix run nixpkgs.niv -c niv"
        fi

        $niv add $package | sed -u 's/\x1b\[[0-9;]*m//g'
        sleep 1
      '';
    in
    ''
      if !exists('g:airline_symbols')
        let g:airline_symbols = {}
      endif

      let g:airline_symbols.maxlinenr = ' ln'
      let g:airline_symbols.branch = '⭠'

      let g:airline#extensions#tabline#enabled = 1
      let g:airline#extensions#tabline#formatter = 'unique_tail'
      let g:airline#extensions#tabline#show_tabs = 0

      let g:airline#extensions#nvimlsp#enabled = 0

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
      set autochdir
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
      set foldmethod=marker
      command -nargs=* Hm !home-manager <args>
      autocmd VimEnter * hi Comment cterm=italic gui=italic
      autocmd VimEnter * hi Folded cterm=bold ctermfg=DarkBlue ctermbg=none
      autocmd VimEnter * hi FoldColumn cterm=bold ctermfg=DarkBlue ctermbg=none
      vnoremap <C-c> "*y
      vnoremap <C-x> "*d
      cnoremap <Up> <C-p>
      cnoremap <Down> <C-n>
      nnoremap hms :Hm switch
      nnoremap hmb :Hm build
      nnoremap <Space> za
      map <Leader>niv :s/$/ /<CR>^v$:w !${nivscript}<CR>wv^deld$viwyA = sources.<esc>pA;
    '';
  };
}
