{ config, lib, pkgs, inputs, ... }:
let
  sources = (inputs.get-flake ./plugins).inputs;
in
{
  stylix.targets.neovim.enable = true;

  home.sessionVariables.EDITOR = "nvim";

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withPython3 = true;
    extraPackages = with pkgs; [
      nil
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
            "command" = "nil";
            "filetypes" = [ "nix" ];
            "rootPatterns" = [ "flake.nix" ];
          };
        };
        "pyright" = {
          "inlayHints"."enable" = false;
        };
      };
    };
    plugins = with pkgs.vimPlugins; [
      camelcasemotion
      caw-vim
      coc-pyright
      context_filetype-vim
      copilot-vim
      editorconfig-vim
      {
        plugin = galaxyline-nvim;
        type = "lua";
        config = with config.lib.stylix.colors; ''
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
      {
        plugin = indent-blankline-nvim;
        type = "lua";
        config = ''
          require "ibl".setup {
            indent = { char = '┊' },
          }
        '';
      }
      vim-suda
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
      vim-trailing-whitespace
      vim-unimpaired
    ] ++ lib.attrsets.mapAttrsToList (name: src:
      let
        pname = name;
        version = builtins.substring 0 7 src.rev;
      in
      pkgs.vimUtils.buildVimPlugin {
        inherit pname version src;
      }
    ) sources;
    extraConfig = ''
      let g:suda_smart_edit = 1

      set termguicolors
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

      " Make line wrapping nicer
      set breakindent
      set formatoptions=l
      set lbr
      set virtualedit=
      set wrap linebreak nolist
      set display+=lastline
      inoremap <expr><buffer> <silent> <Up>   coc#pum#visible() ? coc#pum#prev(1) : "\<C-o>gk"
      inoremap <expr><buffer> <silent> <Down> coc#pum#visible() ? coc#pum#next(1) : "\<C-o>gj"
      noremap <silent> <Up>   gk
      noremap <silent> <Down> gj
      noremap <silent> k gk
      noremap <silent> j gj

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

      let mapleader=','
      nmap <Leader>a= :Tabularize /=<CR>
      nmap <Leader>c :%s/\s\+$//e<Return>``
      vmap <Leader>c :%s/\s\+$//e<Return>``
      vmap <Leader>a= :Tabularize /=<CR>
      nmap <Leader>a: :Tabularize /:\zs<CR>
      vmap <Leader>a: :Tabularize /:\zs<CR>
      vmap <Leader>A :s/$/
      vmap <Leader>t :Tabularize /
      nmap <Leader>t :Tabularize /
      nmap <Leader>n :noh<Return>
      nnoremap <Leader>hms :!hms
      nnoremap <Leader>hmb :!home-manager build
      nnoremap <Leader><Space> :ToggleBool<CR>

      map <silent> w <Plug>CamelCaseMotion_w
      map <silent> b <Plug>CamelCaseMotion_b
      map <silent> e <Plug>CamelCaseMotion_e
      map <silent> ge <Plug>CamelCaseMotion_ge
      sunmap w
      sunmap b
      sunmap e
      sunmap ge

      set expandtab
      set mouse=a
      set noshowmode
      set foldmethod=marker
      autocmd VimEnter * hi Comment cterm=italic gui=italic
      autocmd VimEnter * hi Folded cterm=bold ctermfg=DarkBlue ctermbg=none
      autocmd VimEnter * hi FoldColumn cterm=bold ctermfg=DarkBlue ctermbg=none

      aunmenu PopUp.How-to\ disable\ mouse
      aunmenu PopUp.-1-

      hi CocSearch ctermfg=DarkBlue

      " https://stackoverflow.com/questions/1327978/sorting-words-not-lines-in-vim/1328421#1328421
      " sort words in line with SortLine
      command -nargs=0 -range SortLine <line1>,<line2>call setline('.',join(sort(split(getline('.'),' ')),' '))

      " https://vi.stackexchange.com/questions/454/whats-the-simplest-way-to-strip-trailing-whitespace-from-all-lines-in-a-file
      fun! TrimWhitespace()
          let l:save = winsaveview()
          keeppatterns %s/\s\+$//e
          call winrestview(l:save)
      endfun

      command! TrimWhitespace call TrimWhitespace()

      " command mode completion navigation
      cnoremap <Up> <C-p>
      cnoremap <Down> <C-n>

      " esc to exit terminal mode
      tnoremap <Esc> <C-\><C-n>

      inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm() : "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"
      inoremap <silent><expr> <C-x><C-z> coc#pum#visible() ? coc#pum#stop() : "\<C-x>\<C-z>"
      " remap for complete to use tab and <cr>
      inoremap <silent><expr> <TAB>
            \ coc#pum#visible() ? coc#pum#next(1):
            \ <SID>check_back_space() ? "\<TAB>" :
            \ coc#refresh()
      inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"
      inoremap <silent><expr> <c-space> coc#refresh()

      " https://vim.fandom.com/wiki/Move_cursor_by_display_lines_when_wrapping
      noremap <silent> <Leader>w :call ToggleWrap()<CR>
      function ToggleWrap()
        if &wrap
          echo "Wrap OFF"
          setlocal nowrap
          set virtualedit=all
          silent! nunmap <buffer> <Up>
          silent! nunmap <buffer> <Down>
          silent! nunmap <buffer> <Home>
          silent! nunmap <buffer> <End>
          silent! iunmap <buffer> <Up>
          silent! iunmap <buffer> <Down>
          silent! iunmap <buffer> <Home>
          silent! iunmap <buffer> <End>
        else
          echo "Wrap ON"
          setlocal wrap linebreak nolist
          set virtualedit=
          setlocal display+=lastline
          noremap  <buffer> <silent> <Up>   gk
          noremap  <buffer> <silent> <Down> gj
          noremap  <buffer> <silent> <Home> g<Home>
          noremap  <buffer> <silent> <End>  g<End>
          inoremap <buffer> <silent> <Up>   <C-o>gk
          inoremap <buffer> <silent> <Down> <C-o>gj
          inoremap <buffer> <silent> <Home> <C-o>g<Home>
          inoremap <buffer> <silent> <End>  <C-o>g<End>
        endif
      endfunction
      noremap <silent> k gk
      noremap <silent> j gj
      noremap <silent> 0 g0
      noremap <silent> $ g$

      function! s:check_back_space() abort
        let col = col('.') - 1
        return !col || getline('.')[col - 1]  =~# '\s'
      endfunction

      " automatic \v for search
      nnoremap / /\v
      vnoremap / /\v

      nnoremap <F5> :UndotreeToggle<CR>

      " https://stackoverflow.com/questions/597687/how-to-quickly-change-variable-names-in-vim/597932#597932
      nnoremap gR gD:%s/<C-R>///gc<left><left><left>
      nnoremap <Space> za

      luafile ${builtins.toFile "generatedConfig.lua" config.programs.neovim.generatedConfigs.lua}
    '';
  };
}
