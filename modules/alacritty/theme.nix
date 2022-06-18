{ config, ...}:

# copied from
# https://github.com/aarowill/base16-alacritty/blob/master/templates/default.mustache
with config.colorScheme.colors; builtins.toFile "alacritty-theme.yaml" ''
colors:
  # Default colors
  primary:
    background: '0x${base00}'
    foreground: '0x${base05}'

  # Colors the cursor will use if `custom_cursor_colors` is true
  cursor:
    text: '0x${base00}'
    cursor: '0x${base05}'

  # Normal colors
  normal:
    black:   '0x${base00}'
    red:     '0x${base08}'
    green:   '0x${base0B}'
    yellow:  '0x${base0A}'
    blue:    '0x${base0D}'
    magenta: '0x${base0E}'
    cyan:    '0x${base0C}'
    white:   '0x${base05}'

  # Bright colors
  bright:
    black:   '0x${base03}'
    red:     '0x${base08}'
    green:   '0x${base0B}'
    yellow:  '0x${base0A}'
    blue:    '0x${base0D}'
    magenta: '0x${base0E}'
    cyan:    '0x${base0C}'
    white:   '0x${base05}'

draw_bold_text_with_bright_colors: false
''
