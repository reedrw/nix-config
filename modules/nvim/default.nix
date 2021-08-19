{ config, lib, pkgs, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    plugins = with pkgs.vimPlugins; [
      #nvim-bufferline-lua
      ale
      base16-vim
      caw-vim
      context_filetype-vim
      deoplete-nvim
      direnv-vim
      editorconfig-vim
      galaxyline-nvim
      indent-blankline-nvim
      suda-vim
      targets-vim
      undotree
      vim-dirvish
      vim-eunuch
      vim-exchange
      vim-fugitive
      vim-gitgutter
      #tabular
      vim-lion
      vim-operator-user
      vim-polyglot
      vim-projectionist
      vim-repeat
      vim-sandwich
      vim-table-mode
      vim-unimpaired
    ];
    extraConfig = with config.lib.base16; ''
      let g:deoplete#enable_at_startup = 1
      let g:indentLine_char = '┊'
      let g:suda_smart_edit = 1

      set termguicolors
      source ${base16template "vim"}
      let base16colorspace=256

      " disable language packs
      let g:polyglot_disabled = [
      \ "sensible",
      \]

      syntax on
      set t_Co=256
      set title
      set number
      set numberwidth=5
      set cursorline
      set inccommand=nosplit

      " until neovim/neovim/issues/14209 is fixed
      set colorcolumn=99999

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

      " Don't unload abandoned buffers
      set hidden
      set updatetime=1000
      set shiftwidth=2
      set tabstop=8
      set expandtab
      set mouse=a
      set noshowmode
      set foldmethod=marker
      autocmd VimEnter * hi Comment cterm=italic gui=italic
      autocmd VimEnter * hi Folded cterm=bold ctermfg=DarkBlue ctermbg=none
      autocmd VimEnter * hi FoldColumn cterm=bold ctermfg=DarkBlue ctermbg=none
      " https://stackoverflow.com/questions/1327978/sorting-words-not-lines-in-vim/1328421#1328421
      " sort words in line with SortLine
      command -nargs=0 -range SortLine <line1>,<line2>call setline('.',join(sort(split(getline('.'),' ')),' '))
      vnoremap <C-c> "+y
      vnoremap <C-x> "+d

      " command mode completion navigation
      cnoremap <Up> <C-p>
      cnoremap <Down> <C-n>

      " automatic \v for search
      nnoremap / /\v
      vnoremap / /\v

      nnoremap hms :!home-manager switch
      nnoremap hmb :!home-manager build
      " https://stackoverflow.com/questions/597687/how-to-quickly-change-variable-names-in-vim/597932#597932
      nnoremap gR gD:%s/<C-R>///gc<left><left><left>
      nnoremap <Space> za
    '';
  };
}
