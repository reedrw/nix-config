{ config, lib, pkgs, ... }:
let
  sources = import ../../functions/sources.nix { sourcesFile = ./nix/sources.json; };

  nivMap = import ../../functions/nivMap.nix;

  attrList = nivMap sources;

  pluginList = builtins.map ( x:
    pkgs.vimUtils.buildVimPlugin {
      name = x.repo;
      src = builtins.fetchTarball {
        url = x.url;
        sha256 = x.sha256;
      };
      dontBuild = true;
      dontConfigure = true;
    }
  ) attrList;

  nvimNightly = pkgs.neovim-unwrapped.overrideAttrs (
    old: rec {
      version = "nightly";
      src = pkgs.fetchFromGitHub (lib.importJSON ./nightly.json);

      buildInputs = old.buildInputs ++ [ pkgs.tree-sitter ];
      cmakeFlags = old.cmakeFlags ++ [ "-DUSE_BUNDLED=OFF" ];
    }
  );

in
{

  programs.neovim = {
    enable = true;
    package = nvimNightly;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = pluginList;
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
      let g:deoplete#enable_at_startup = 1
      let g:indentLine_char = '┊'
      let g:suda_smart_edit = 1

      set termguicolors
      source ${base16template "vim"}
      let base16colorspace=256

      syntax on
      set autochdir
      set t_Co=256
      set title
      set number
      set numberwidth=5
      set cursorline
      set inccommand=nosplit

      lua << EOF
      local colors = {
        blank = '#${theme.base00-hex}',
        bg = '#${theme.base01-hex}',
        section_bg = '#${theme.base02-hex}',
        gray = '#${theme.base03-hex}',
        fg = '#${theme.base05-hex}',
        red = '#${theme.base08-hex}',
        orange = '#${theme.base09-hex}',
        yellow = '#${theme.base0A-hex}',
        green = '#${theme.base0B-hex}',
        cyan = '#${theme.base0C-hex}',
        blue = '#${theme.base0D-hex}',
        magenta = '#${theme.base0E-hex}',
        brown = '#${theme.base0F-hex}'
      }

      ${builtins.readFile ./lua/bufferline.lua}
      ${builtins.readFile ./lua/galaxyline.lua}
      EOF

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
      autocmd VimEnter * hi Comment cterm=italic gui=italic
      autocmd VimEnter * hi Folded cterm=bold ctermfg=DarkBlue ctermbg=none
      autocmd VimEnter * hi FoldColumn cterm=bold ctermfg=DarkBlue ctermbg=none
      vnoremap <C-c> "*y
      vnoremap <C-x> "*d
      cnoremap <Up> <C-p>
      cnoremap <Down> <C-n>
      nnoremap hms :!home-manager switch
      nnoremap hmb :!home-manager build
      " https://stackoverflow.com/questions/597687/how-to-quickly-change-variable-names-in-vim/597932#597932
      nnoremap gR gD:%s/<C-R>///gc<left><left><left>
      nnoremap <Space> za
      map <Leader>niv :s/$/ /<CR>^v$:w !${nivscript}<CR>wv^deld$viwyA = sources.<esc>pA;
      map tn :tabnew<Return>
      map tq :Sayonara<Return>
    '';
  };
}
