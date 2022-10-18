{ config, lib, pkgs, ... }:
let
  sources = import ./nix/sources.nix { };
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withPython3 = true;
    extraPackages = with pkgs; [
      rnix-lsp
    ];
    extraPython3Packages = (ps: with ps; [
      black
      flake8
      jedi
    ]);
    coc = {
      enable = true;
      settings = {
        "languageserver" = {
          "nix" = {
            "command" = "rnix-lsp";
            "filetypes" = [ "nix" ];
          };
        };
        "pyright" = {
          "inlayHints"."enable" = false;
        };
      };
    };
    plugins = with pkgs.vimPlugins; [
      ale
      base16-vim
      caw-vim
      coc-pyright
      context_filetype-vim
      editorconfig-vim
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
      vim-operator-user
      vim-polyglot
      vim-projectionist
      vim-repeat
      vim-sandwich
      vim-table-mode
      vim-unimpaired
    ] ++ lib.attrsets.mapAttrsToList (name: src:
      let
        pname = name;
        version = src.rev;
      in
      pkgs.vimUtils.buildVimPlugin {
        inherit pname version src;
      }
    ) sources;
    extraConfig = with config.colorScheme.colors; ''
      let g:indentLine_char = '┊'
      let g:suda_smart_edit = 1

      set termguicolors
      source ${import ./theme.nix { inherit config; } }
      let base16colorspace=256

      let g:fugitive_dynamic_colors = 0
      let g:lc3_detect_asm = 1

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

      " Makes regex syntax highlighting significantly faster
      set re=1

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

      " tab width settings
      set shiftwidth=2
      set tabstop=8

      " auto-update gitgutter
      set updatetime=40

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

      hi CocSearch ctermfg=DarkBlue

      " https://stackoverflow.com/questions/1327978/sorting-words-not-lines-in-vim/1328421#1328421
      " sort words in line with SortLine
      command -nargs=0 -range SortLine <line1>,<line2>call setline('.',join(sort(split(getline('.'),' ')),' '))

      " command mode completion navigation
      cnoremap <Up> <C-p>
      cnoremap <Down> <C-n>

      inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
      inoremap <silent><expr> <C-x><C-z> coc#pum#visible() ? coc#pum#stop() : "\<C-x>\<C-z>"
      " remap for complete to use tab and <cr>
      inoremap <silent><expr> <TAB>
            \ coc#pum#visible() ? coc#pum#next(1):
            \ <SID>check_back_space() ? "\<TAB>" :
            \ coc#refresh()
      inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
      inoremap <silent><expr> <c-space> coc#refresh()

      function! s:check_back_space() abort
        let col = col('.') - 1
        return !col || getline('.')[col - 1]  =~# '\s'
      endfunction

      " automatic \v for search
      nnoremap / /\v
      vnoremap / /\v

      nnoremap <F5> :UndotreeToggle<CR>

      nnoremap hms :!home-manager switch
      nnoremap hmb :!home-manager build
      " https://stackoverflow.com/questions/597687/how-to-quickly-change-variable-names-in-vim/597932#597932
      nnoremap gR gD:%s/<C-R>///gc<left><left><left>
      nnoremap <Space> za

      luafile ${pkgs.writeText "generatedConfig.lua" config.programs.neovim.generatedConfigs.lua}
    '';
  };
}
