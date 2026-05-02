local wezterm = require('wezterm')
local umath = require('utils.math')

local nf = wezterm.nerdfonts
local M = {}

local SEPARATOR_CHAR = nf.oct_dash .. ' '

local discharging_icons = {
   nf.md_battery_10, nf.md_battery_20, nf.md_battery_30,
   nf.md_battery_40, nf.md_battery_50, nf.md_battery_60,
   nf.md_battery_70, nf.md_battery_80, nf.md_battery_90,
   nf.md_battery,
}
local charging_icons = {
   nf.md_battery_charging_10, nf.md_battery_charging_20, nf.md_battery_charging_30,
   nf.md_battery_charging_40, nf.md_battery_charging_50, nf.md_battery_charging_60,
   nf.md_battery_charging_70, nf.md_battery_charging_80, nf.md_battery_charging_90,
   nf.md_battery_charging,
}

local colors = {
   date_fg      = '#fab387',
   date_bg      = 'rgba(0, 0, 0, 0.4)',
   battery_fg   = '#f9e2af',
   battery_bg   = 'rgba(0, 0, 0, 0.4)',
   cpu_fg       = '#a6e3a1',
   cpu_bg       = 'rgba(0, 0, 0, 0.4)',
   mem_fg       = '#89b4fa',
   mem_bg       = 'rgba(0, 0, 0, 0.4)',
   gpu_fg       = '#cba6f7',
   gpu_bg       = 'rgba(0, 0, 0, 0.4)',
   net_fg       = '#94e2d5',
   net_bg       = 'rgba(0, 0, 0, 0.4)',
   -- git_fg    = '#f38ba8',  -- Git 分支颜色（备用）
   -- weather_fg = '#89dceb', -- 天气颜色（备用）
   separator_fg = '#74c7ec',
   separator_bg = 'rgba(0, 0, 0, 0.4)',
}

-- 缓存系统信息，每5秒更新一次
local _cache = {
   cpu          = '?%',
   mem          = '?/?GB',
   gpu          = '?%',
   net_up       = '?',
   net_down     = '?',
   -- git_branch = '?',   -- Git 分支缓存（备用）
   -- weather    = '?',   -- 天气缓存（备用）
   last_update  = 0,
   -- 用于计算网速的上次流量数据
   last_net_sent = 0,
   last_net_recv = 0,
}

local __cells__ = {}

local _push = function(text, icon, fg, bg, separate)
   table.insert(__cells__, { Foreground = { Color = fg } })
   table.insert(__cells__, { Background = { Color = bg } })
   table.insert(__cells__, { Attribute = { Intensity = 'Bold' } })
   table.insert(__cells__, { Text = icon .. ' ' .. text .. ' ' })

   if separate then
      table.insert(__cells__, { Foreground = { Color = colors.separator_fg } })
      table.insert(__cells__, { Background = { Color = colors.separator_bg } })
      table.insert(__cells__, { Text = SEPARATOR_CHAR })
   end
end

-- 格式化网速，自动换算单位
local _format_speed = function(bytes_per_sec)
   if bytes_per_sec >= 1024 * 1024 then
      return string.format('%.1fMB/s', bytes_per_sec / 1024 / 1024)
   elseif bytes_per_sec >= 1024 then
      return string.format('%.1fKB/s', bytes_per_sec / 1024)
   else
      return string.format('%dB/s', bytes_per_sec)
   end
end

local _update_sys_info = function()
   local now = os.time()
   if now - _cache.last_update < 5 then
      return
   end
   local elapsed = now - _cache.last_update
   _cache.last_update = now

   -- CPU
   local cpu_ok, cpu_out = wezterm.run_child_process({
      'powershell', '-NoProfile', '-Command',
      '(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average'
   })
   if cpu_ok and cpu_out then
      local val = cpu_out:gsub('%s+', '')
      if val ~= '' then
         _cache.cpu = val .. '%'
      end
   end

   -- 内存
   local mem_ok, mem_out = wezterm.run_child_process({
      'powershell', '-NoProfile', '-Command',
      '$m = Get-CimInstance Win32_OperatingSystem; ' ..
      '$used = [math]::Round(($m.TotalVisibleMemorySize - $m.FreePhysicalMemory) / 1MB, 1); ' ..
      '$total = [math]::Round($m.TotalVisibleMemorySize / 1MB, 1); ' ..
      'Write-Output "$used/$total"'
   })
   if mem_ok and mem_out then
      local val = mem_out:gsub('%s+', '')
      if val ~= '' then
         _cache.mem = val .. 'GB'
      end
   end

   -- GPU（需要 NVIDIA 显卡，如果是 AMD/Intel 可注释掉）
   local gpu_ok, gpu_out = wezterm.run_child_process({
      'powershell', '-NoProfile', '-Command',
      'nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits'
   })
   if gpu_ok and gpu_out then
      local val = gpu_out:gsub('%s+', '')
      if val ~= '' then
         _cache.gpu = val .. '%'
      end
   end
   -- AMD 显卡版本（取消注释使用）：
   -- local gpu_ok, gpu_out = wezterm.run_child_process({
   --    'powershell', '-NoProfile', '-Command',
   --    '(Get-CimInstance Win32_VideoController | Select-Object -First 1).CurrentRefreshRate'
   -- })

   -- 网速
   local net_ok, net_out = wezterm.run_child_process({
      'powershell', '-NoProfile', '-Command',
      '$n = Get-CimInstance Win32_PerfRawData_Tcpip_NetworkInterface | ' ..
      'Measure-Object -Property BytesSentPersec,BytesReceivedPersec -Sum; ' ..
      '$sent = ($n | Where-Object Property -eq BytesSentPersec).Sum; ' ..
      '$recv = ($n | Where-Object Property -eq BytesReceivedPersec).Sum; ' ..
      'Write-Output "$sent $recv"'
   })
   if net_ok and net_out then
      local sent, recv = net_out:match('(%d+)%s+(%d+)')
      if sent and recv then
         sent = tonumber(sent)
         recv = tonumber(recv)
         if _cache.last_net_sent > 0 and elapsed > 0 then
            local up_speed = (sent - _cache.last_net_sent) / elapsed
            local down_speed = (recv - _cache.last_net_recv) / elapsed
            _cache.net_up   = _format_speed(math.max(0, up_speed))
            _cache.net_down = _format_speed(math.max(0, down_speed))
         end
         _cache.last_net_sent = sent
         _cache.last_net_recv = recv
      end
   end

   -- Git 分支（备用，取消注释使用）
   -- local git_ok, git_out = wezterm.run_child_process({
   --    'git', 'rev-parse', '--abbrev-ref', 'HEAD'
   -- })
   -- if git_ok and git_out then
   --    local val = git_out:gsub('%s+', '')
   --    if val ~= '' then
   --       _cache.git_branch = val
   --    end
   -- end

   -- 天气（备用，需要替换 YOUR_CITY，取消注释使用）
   -- local weather_ok, weather_out = wezterm.run_child_process({
   --    'powershell', '-NoProfile', '-Command',
   --    '(Invoke-RestMethod "wttr.in/YOUR_CITY?format=%t").Trim()'
   -- })
   -- if weather_ok and weather_out then
   --    local val = weather_out:gsub('%s+', '')
   --    if val ~= '' then
   --       _cache.weather = val
   --    end
   -- end
end

local _set_date = function()
   local date = wezterm.strftime(' %a %H:%M:%S')
   _push(date, nf.fa_calendar, colors.date_fg, colors.date_bg, true)
end

local _set_battery = function()
   local charge = ''
   local icon = ''
   for _, b in ipairs(wezterm.battery_info()) do
      local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
      charge = string.format('%.0f%%', b.state_of_charge * 100)
      if b.state == 'Charging' then
         icon = charging_icons[idx]
      else
         icon = discharging_icons[idx]
      end
   end
   if charge ~= '' then
      _push(charge, icon, colors.battery_fg, colors.battery_bg, true)
   end
end

local _set_cpu = function()
   _push(_cache.cpu, nf.md_cpu_64_bit, colors.cpu_fg, colors.cpu_bg, true)
end

local _set_mem = function()
   _push(_cache.mem, nf.md_memory, colors.mem_fg, colors.mem_bg, true)
end

local _set_gpu = function()
   _push(_cache.gpu, nf.md_expansion_card, colors.gpu_fg, colors.gpu_bg, true)
end

local _set_net = function()
   local net_text = '↑' .. _cache.net_up .. ' ↓' .. _cache.net_down
   _push(net_text, nf.md_network, colors.net_fg, colors.net_bg, true)
end

-- Git 分支（备用）
-- local _set_git = function()
--    _push(_cache.git_branch, nf.dev_git_branch, colors.git_fg, colors.git_bg, true)
-- end

-- 天气（备用）
-- local _set_weather = function()
--    _push(_cache.weather, nf.md_weather_partly_cloudy, colors.weather_fg, colors.weather_bg, true)
-- end

M.setup = function()
   wezterm.on('update-right-status', function(window, _pane)
      __cells__ = {}
      _update_sys_info()
      _set_net()
      _set_gpu()
      _set_cpu()
      _set_mem()
      _set_battery()
      _set_date()
      window:set_right_status(wezterm.format(__cells__))
   end)
end

return M