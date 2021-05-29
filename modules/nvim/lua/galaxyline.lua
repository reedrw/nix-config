function is_buffer_empty()
  -- Check whether the current buffer is empty
  return vim.fn.empty(vim.fn.expand('%:t')) == 1
end

function has_width_gt(cols)
  -- Check if the windows width is greater than a given number of columns
  return vim.fn.winwidth(0) / 2 > cols
end

local gl = require('galaxyline')
local condition = require('galaxyline.condition')
local fileinfo = require('galaxyline.provider_fileinfo')
local vcs = require('galaxyline.provider_vcs')

local gls = gl.section
gl.short_line_list = { 'NvimTree', 'defx', 'packager', 'vista', 'zsh', 'TERMINAL' }

-- Local helper functions
local buffer_not_empty = function()
  return not is_buffer_empty()
end

local checkwidth = function()
  return has_width_gt(40) and buffer_not_empty()
end

local mode_color = function()
  local mode_colors = {
    n = colors.blue,
    i = colors.green,
    c = colors.orange,
    V = colors.orange,
    [''] = colors.orange,
    v = colors.magenta,
    R = colors.red,
    t = colors.orange
  }

  return mode_colors[vim.fn.mode()]
end

-- Left side
gls.left[2] = {
  ViMode = {
    provider = function()
      local alias = {
        n = '  N ',
        i = '  I ',
        c = '  C ',
        v = '  V ',
        V = ' V-L',
        [''] = ' V-B',
        R = '  R ',
        t = '  T '
      }
      vim.api.nvim_command('hi GalaxyViMode guibg='..mode_color())
      return ' '..alias[vim.fn.mode()]..' '
    end,
    highlight = { colors.bg, colors.bg },
  },
}

gls.left[4] = {
  FileName = {
    provider = { function() return '  ' end,
    function()
      local current = vim.fn.expand('%:t')
      local filename = (current == '' and '[No Name]' or current)

      filename = string.gsub(filename, '^%s*(.-)%s*$', '%1')

      return ' ' .. filename .. ' '
    end,
    'FileSize' },
    condition = buffer_not_empty,
    highlight = { colors.fg, colors.section_bg },
    separator_highlight = {colors.section_bg, colors.bg},
  }
}
gls.left[5] = {
  GitIcon = {
    provider =  function() return '   ' end,
    condition = condition.check_git_workspace,
    highlight = {colors.red,colors.bg},
  }
}
gls.left[6] = {
  GitBranch = {
    provider = { 'GitBranch', function() return ' ' end },
    condition = condition.check_git_workspace,
    highlight = {colors.fg,colors.bg},
  }
}
gls.left[7] = {
  DiffAdd = {
    provider = 'DiffAdd',
    condition = checkwidth,
    icon = '+',
    highlight = { colors.green, colors.bg },
  }
}
gls.left[8] = {
  DiffModified = {
    provider = 'DiffModified',
    condition = checkwidth,
    icon = '~',
    highlight = { colors.orange, colors.bg },
  }
}
gls.left[9] = {
  DiffRemove = {
    provider = 'DiffRemove',
    condition = checkwidth,
    icon = '-',
    highlight = { colors.red,colors.bg },
  }
}

gls.left[11] = {
  EndGit = {
    provider = function () return '▏' end,
    condition = condition.check_git_workspace,
    highlight = { colors.section_bg,colors.bg },
  }
}
gls.left[12] = {
  EndLeft = {
    provider = function () return ' ' end,
    highlight = { colors.bg,colors.bg },
  }
}

-- Right side
gls.right[1]= {
  FileFormat = {
    provider = function() return vim.bo.filetype..' ' end,
    highlight = { colors.fg,colors.bg },
  }
}
gls.right[2] = {
  FileEncode = {
    provider = { 'FileEncode', function() return '  ' end },
    separator = ' ',
    highlight = { colors.fg, colors.section_bg},
    separator_highlight = { colors.fg, colors.section_bg},
  }
}
gls.right[3] = {
  LineInfo = {
    provider = function()
      local line = vim.fn.line('.')
      local column = vim.fn.col('.')
      --return string.format("%3d :%2d ", line, column)
      vim.api.nvim_command('hi GalaxyLineInfo guibg='..mode_color())
      return '  ' .. fileinfo.current_line_percent('result') .. ' ' .. ' ' .. line .. ":" .. column .. ' '
    end,
    --provider = 'LineColumn',
    highlight = { colors.bg, colors.bg },
  }
}

-- Force manual load so that nvim boots with a status line
gl.load_galaxyline()
