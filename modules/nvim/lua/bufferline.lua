require('bufferline').setup {
  options = {
    buffer_close_icon = "✕",
    show_buffer_icons = false,
    show_close_icon = true,
    indicator_icon = ' ',
    max_name_length = 14,
    separator_style = { "", "" },
  },
  highlights = {
    fill = {
      guibg = "none"
    },
    background = {
        guibg = "none"
    },
    tab = {
        guibg = "none"
    },
    duplicate = {
        guibg = "none"
    },
    buffer_selected = {
      guibg = colors.section_bg
    },
    indicator_selected = {
      guibg = colors.blue,
      guifg = colors.blue
    },
    modified_selected = {
      guibg = colors.section_bg,
      guifg = colors.green
    },
    modified = {
      guibg = colors.blank,
      guifg = colors.green
    },
    close_button_visible = {
      guifg = colors.blank,
      guifg = colors.fg
    },
    close_button_selected = {
      guibg = colors.section_bg,
      guifg = colors.fg
    },
  }
}
