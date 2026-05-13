local wezterm = require("wezterm")
local umath = require("utils.math")

local nf = wezterm.nerdfonts
local M = {}

local SEPARATOR_CHAR = nf.oct_dash .. " "

local is_windows = wezterm.target_triple:find("windows") ~= nil
local is_mac = wezterm.target_triple:find("apple") ~= nil
local is_linux = not is_windows and not is_mac

local discharging_icons = {
	nf.md_battery_10,
	nf.md_battery_20,
	nf.md_battery_30,
	nf.md_battery_40,
	nf.md_battery_50,
	nf.md_battery_60,
	nf.md_battery_70,
	nf.md_battery_80,
	nf.md_battery_90,
	nf.md_battery,
}
local charging_icons = {
	nf.md_battery_charging_10,
	nf.md_battery_charging_20,
	nf.md_battery_charging_30,
	nf.md_battery_charging_40,
	nf.md_battery_charging_50,
	nf.md_battery_charging_60,
	nf.md_battery_charging_70,
	nf.md_battery_charging_80,
	nf.md_battery_charging_90,
	nf.md_battery_charging,
}

local colors = {
	date_fg = "#fab387",
	date_bg = "rgba(0, 0, 0, 0.4)",
	battery_fg = "#f9e2af",
	battery_bg = "rgba(0, 0, 0, 0.4)",
	cpu_fg = "#a6e3a1",
	cpu_bg = "rgba(0, 0, 0, 0.4)",
	mem_fg = "#89b4fa",
	mem_bg = "rgba(0, 0, 0, 0.4)",
	gpu_fg = "#cba6f7",
	gpu_bg = "rgba(0, 0, 0, 0.4)",
	net_fg = "#94e2d5",
	net_bg = "rgba(0, 0, 0, 0.4)",
	separator_fg = "#74c7ec",
	separator_bg = "rgba(0, 0, 0, 0.4)",
}

local _cache = {
	cpu = "?%",
	mem = "?/?GB",
	gpu = "?%",
	net_up = "?",
	net_down = "?",
	last_update = 0,
	last_net_sent = 0,
	last_net_recv = 0,
}

local __cells__ = {}

local _push = function(text, icon, fg, bg, separate)
	table.insert(__cells__, { Foreground = { Color = fg } })
	table.insert(__cells__, { Background = { Color = bg } })
	table.insert(__cells__, { Attribute = { Intensity = "Bold" } })
	table.insert(__cells__, { Text = icon .. " " .. text .. " " })
	if separate then
		table.insert(__cells__, { Foreground = { Color = colors.separator_fg } })
		table.insert(__cells__, { Background = { Color = colors.separator_bg } })
		table.insert(__cells__, { Text = SEPARATOR_CHAR })
	end
end

local _format_speed = function(bytes_per_sec)
	if bytes_per_sec >= 1024 * 1024 then
		return string.format("%.1fMB/s", bytes_per_sec / 1024 / 1024)
	elseif bytes_per_sec >= 1024 then
		return string.format("%.1fKB/s", bytes_per_sec / 1024)
	else
		return string.format("%dB/s", bytes_per_sec)
	end
end

-- ─── Windows ────────────────────────────────────────────────────────────────

local _update_windows = function(elapsed)
	-- CPU
	local ok, out = wezterm.run_child_process({
		"powershell",
		"-NoProfile",
		"-Command",
		"(Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average",
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.cpu = val .. "%"
		end
	end

	-- 内存
	ok, out = wezterm.run_child_process({
		"powershell",
		"-NoProfile",
		"-Command",
		"$m = Get-CimInstance Win32_OperatingSystem; "
			.. "$used = [math]::Round(($m.TotalVisibleMemorySize - $m.FreePhysicalMemory) / 1MB, 1); "
			.. "$total = [math]::Round($m.TotalVisibleMemorySize / 1MB, 1); "
			.. 'Write-Output "$used/$total"',
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.mem = val .. "GB"
		end
	end

	-- GPU（NVIDIA）
	ok, out = wezterm.run_child_process({
		"powershell",
		"-NoProfile",
		"-Command",
		"nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits",
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.gpu = val .. "%"
		end
	end

	-- 网速
	ok, out = wezterm.run_child_process({
		"powershell",
		"-NoProfile",
		"-Command",
		"$n = Get-CimInstance Win32_PerfRawData_Tcpip_NetworkInterface | "
			.. "Measure-Object -Property BytesSentPersec,BytesReceivedPersec -Sum; "
			.. "$sent = ($n | Where-Object Property -eq BytesSentPersec).Sum; "
			.. "$recv = ($n | Where-Object Property -eq BytesReceivedPersec).Sum; "
			.. 'Write-Output "$sent $recv"',
	})
	if ok and out then
		local sent, recv = out:match("(%d+)%s+(%d+)")
		if sent and recv then
			sent = tonumber(sent)
			recv = tonumber(recv)
			if _cache.last_net_sent > 0 and elapsed > 0 then
				_cache.net_up = _format_speed(math.max(0, (sent - _cache.last_net_sent) / elapsed))
				_cache.net_down = _format_speed(math.max(0, (recv - _cache.last_net_recv) / elapsed))
			end
			_cache.last_net_sent = sent
			_cache.last_net_recv = recv
		end
	end
end

-- ─── macOS ──────────────────────────────────────────────────────────────────

local _update_mac = function(elapsed)
	-- CPU（使用 top 单次采样）
	local ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		'top -l 1 -n 0 | awk \'/CPU usage/ {gsub("%",""); print 100 - $NF}\'',
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.cpu = val .. "%"
		end
	end

	-- 内存（vm_stat）
	ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		[[
         vm_stat | awk '
         /page size/ { ps = $8 }
         /Pages active/ { a = $3+0 }
         /Pages wired/ { w = $4+0 }
         /Pages occupied/ { o = $5+0 }
         END {
            used = (a + w + o) * ps / 1073741824
            cmd = "sysctl -n hw.memsize"
            cmd | getline total_bytes
            total = total_bytes / 1073741824
            printf "%.1f/%.1f", used, total
         }'
      ]],
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.mem = val .. "GB"
		end
	end

	-- GPU（macOS 无通用方案，显示 N/A；有 NVIDIA 外接卡可改用 nvidia-smi）
	_cache.gpu = "N/A"

	-- 网速（netstat -ib，取第一个非 lo 接口）
	ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		[[
         netstat -ib | awk 'NR>1 && $1!~/^lo/ && $1!~/Link/ && $6~/^[0-9]+$/ && $10~/^[0-9]+$/ {
            sent += $10; recv += $7
         } END { print sent, recv }'
      ]],
	})
	if ok and out then
		local sent, recv = out:match("(%d+)%s+(%d+)")
		if sent and recv then
			sent = tonumber(sent)
			recv = tonumber(recv)
			if _cache.last_net_sent > 0 and elapsed > 0 then
				_cache.net_up = _format_speed(math.max(0, (sent - _cache.last_net_sent) / elapsed))
				_cache.net_down = _format_speed(math.max(0, (recv - _cache.last_net_recv) / elapsed))
			end
			_cache.last_net_sent = sent
			_cache.last_net_recv = recv
		end
	end
end

-- ─── Linux ──────────────────────────────────────────────────────────────────

local _update_linux = function(elapsed)
	-- CPU（/proc/stat）
	local ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		[[
         awk '/^cpu / {
            idle=$5; total=$2+$3+$4+$5+$6+$7+$8
            print 100 - int(idle*100/total)
         }' /proc/stat
      ]],
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.cpu = val .. "%"
		end
	end

	-- 内存（/proc/meminfo）
	ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		[[
         awk '/MemTotal/ {total=$2} /MemAvailable/ {avail=$2}
         END { printf "%.1f/%.1f", (total-avail)/1048576, total/1048576 }' /proc/meminfo
      ]],
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.mem = val .. "GB"
		end
	end

	-- GPU（NVIDIA；无卡则显示 N/A）
	ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		"nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null",
	})
	if ok and out then
		local val = out:gsub("%s+", "")
		if val ~= "" then
			_cache.gpu = val .. "%"
		else
			_cache.gpu = "N/A"
		end
	else
		_cache.gpu = "N/A"
	end

	-- 网速（/proc/net/dev，汇总所有非 lo 接口）
	ok, out = wezterm.run_child_process({
		"sh",
		"-c",
		[[
         awk 'NR>2 && !/lo:/ {
            gsub(/:/, " ")
            recv += $2; sent += $10
         } END { print sent, recv }' /proc/net/dev
      ]],
	})
	if ok and out then
		local sent, recv = out:match("(%d+)%s+(%d+)")
		if sent and recv then
			sent = tonumber(sent)
			recv = tonumber(recv)
			if _cache.last_net_sent > 0 and elapsed > 0 then
				_cache.net_up = _format_speed(math.max(0, (sent - _cache.last_net_sent) / elapsed))
				_cache.net_down = _format_speed(math.max(0, (recv - _cache.last_net_recv) / elapsed))
			end
			_cache.last_net_sent = sent
			_cache.last_net_recv = recv
		end
	end
end

-- ─── 调度 ────────────────────────────────────────────────────────────────────

local _update_sys_info = function()
	local now = os.time()
	if now - _cache.last_update < 5 then
		return
	end
	local elapsed = now - _cache.last_update
	_cache.last_update = now

	if is_windows then
		_update_windows(elapsed)
	elseif is_mac then
		_update_mac(elapsed)
	else
		_update_linux(elapsed)
	end
end

-- ─── 状态栏组件 ──────────────────────────────────────────────────────────────

local _set_date = function()
	local date = wezterm.strftime(" %a %H:%M:%S")
	_push(date, nf.fa_calendar, colors.date_fg, colors.date_bg, true)
end

local _set_battery = function()
	local charge = ""
	local icon = ""
	for _, b in ipairs(wezterm.battery_info()) do
		local idx = umath.clamp(umath.round(b.state_of_charge * 10), 1, 10)
		charge = string.format("%.0f%%", b.state_of_charge * 100)
		if b.state == "Charging" then
			icon = charging_icons[idx]
		else
			icon = discharging_icons[idx]
		end
	end
	if charge ~= "" then
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
	-- macOS / 无 NVIDIA 的 Linux 会显示 N/A，可按需注释掉这行
	_push(_cache.gpu, nf.md_expansion_card, colors.gpu_fg, colors.gpu_bg, true)
end

local _set_net = function()
	local net_text = "↑" .. _cache.net_up .. " ↓" .. _cache.net_down
	_push(net_text, nf.md_network, colors.net_fg, colors.net_bg, true)
end

M.setup = function()
	wezterm.on("update-right-status", function(window, _pane)
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

