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
      editorconfig-vim
      #galaxyline-nvim
      {
        plugin = galaxyline-nvim;
        type = "lua";
        config = with config.colorScheme.colors; ''
          local colors = {
            blank = '#${base00}',
            bg = '#${base01}',
            section_bg = '#${base02}',
            gray = '#${base03}',
            fg = '#${base05}',
            red = '#${base08}',
            orange = '#${base09}',
            yellow = '#${base0A}',
            green = '#${base0B}',
            cyan = '#${base0C}',
            blue = '#${base0D}',
            magenta = '#${base0E}',
            brown = '#${base0F}'
          }
        '' + builtins.readFile ./lua/galaxyline.lua;
      }
      indent-blankline-nvim
      suda-vim
      targets-vim
      undotree
      vim-dirvish
      vim-eunuch
      vim-exchange
      vim-fugitive
      vim-gitgutter
      tabular
      # vim-lion
      vim-operator-user
      vim-polyglot
      vim-projectionist
      vim-repeat
      vim-sandwich
      vim-table-mode
      vim-unimpaired
    ];
    extraConfig = with config.colorScheme.colors; ''
      let g:deoplete#enable_at_startup = 1
      let g:indentLine_char = '┊'
      let g:suda_smart_edit = 1

      set termguicolors
      source ${import ./theme.nix { inherit config; } }
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

      " Yank to system clipboard
      if has('clipboard')
        set clipboard=unnamedplus
      end

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

      luafile ${pkgs.writeText "generatedConfig.lua" config.programs.neovim.generatedConfigs.lua}
    '';
  };
}
