local wezterm = require("wezterm")
local platform = require("utils.platform")
local font_size = platform().is_mac and 15 or 14

-- 检测 JetBrains Nerd Font 是否已安装
-- local function is_font_installed(font_name)
-- 	local p = platform()
-- 	if p.is_win then
-- 		local success, stdout = wezterm.run_child_process({
-- 			"powershell",
-- 			"-NoProfile",
-- 			"-Command",
-- 			'[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null; '
-- 				.. "(New-Object System.Drawing.Text.InstalledFontCollection).Families | "
-- 				.. 'Where-Object { $_.Name -like "*'
-- 				.. font_name
-- 				.. '*" } | Select-Object -First 1',
-- 		})
-- 		return success and stdout ~= nil and stdout:gsub("%s+", "") ~= ""
-- 	elseif p.is_mac then
-- 		local success, stdout = wezterm.run_child_process({
-- 			"bash",
-- 			"-c",
-- 			"ls ~/Library/Fonts/ /Library/Fonts/ 2>/dev/null | grep -i '" .. font_name .. "'",
-- 		})
-- 		return success and stdout ~= nil and stdout:gsub("%s+", "") ~= ""
-- 	elseif p.is_linux then
-- 		local success, stdout = wezterm.run_child_process({
-- 			"bash",
-- 			"-c",
-- 			"fc-list | grep -i '" .. font_name .. "'",
-- 		})
-- 		return success and stdout ~= nil and stdout:gsub("%s+", "") ~= ""
-- 	end
-- 	return false
-- end

-- 手动安装字体参考命令（取消注释后在终端执行，不会自动运行）
--
-- Windows（PowerShell 管理员）：
--   $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
--   $zip = "$env:TEMP\JetBrainsMono.zip"
--   $dir = "$env:TEMP\JetBrainsMono"
--   Invoke-WebRequest -Uri $url -OutFile $zip
--   Expand-Archive -Path $zip -DestinationPath $dir -Force
--   $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
--   Get-ChildItem "$dir" -Filter "JetBrainsMonoNLNerdFont-Regular.ttf" -Recurse | ForEach-Object {
--       $fonts.CopyHere($_.FullName, 0x10)
--   }
--
-- macOS：
--   brew install --cask font-jetbrains-mono-nerd-font
--
-- Linux：
--   mkdir -p ~/.local/share/fonts
--   curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
--   unzip -o /tmp/JetBrainsMono.zip "JetBrainsMonoNLNerdFont-Regular.ttf" -d ~/.local/share/fonts/
--   fc-cache -fv

-- 按优先级构建字体列表：有 Nerd Font 就用，没有顺延到下一个
local function build_font_list()
	local candidates = {
		"JetBrainsMonoNL Nerd Font",
		"JetBrainsMono Nerd Font",
		"JetBrains Mono",
		"Consolas",
		"Monaco",
		"DejaVu Sans Mono",
		"Courier New",
	}

	-- 只检测 Nerd Font 变体是否存在，其余系统字体直接放入兜底
	local nerd_variants = {
		["JetBrainsMonoNL Nerd Font"] = "JetBrains",
		["JetBrainsMono Nerd Font"] = "JetBrains",
		["JetBrains Mono"] = "JetBrains",
	}

	local result = {}
	local nerd_found = false

	for _, name in ipairs(candidates) do
		local keyword = nerd_variants[name]
		if keyword then
			if not nerd_found and is_font_installed(keyword) then
				table.insert(result, name)
				nerd_found = true
			end
		else
			-- 系统内置字体，直接加入兜底列表
			table.insert(result, name)
		end
	end

	return result
end

return {
	font = wezterm.font_with_fallback(build_font_list()),
	font_size = font_size,
	freetype_load_target = "Normal",
	freetype_render_target = "Normal",
}
