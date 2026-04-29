local wezterm = require('wezterm')
local platform = require('utils.platform')

local font_size = platform().is_mac and 12 or 12

return {
   -- font = wezterm.font_with_fallback({
   --    'JetBrainsMonoNL Nerd Font',
   --    '鸿蒙黑体',
   -- }),
   font = wezterm.font_with_fallback({
      'Consolas',           -- Windows 内置
      'Monaco',             -- macOS 内置
      'DejaVu Sans Mono',   -- Linux 常见内置
      'Courier New',        -- 三平台都有，最终兜底
   }),
   font_size = font_size,

   --ref: https://wezfurlong.org/wezterm/config/lua/config/freetype_pcf_long_family_names.html#why-doesnt-wezterm-use-the-distro-freetype-or-match-its-configuration
   freetype_load_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
   freetype_render_target = 'Normal', ---@type 'Normal'|'Light'|'Mono'|'HorizontalLcd'
}
