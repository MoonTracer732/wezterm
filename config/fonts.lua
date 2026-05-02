local wezterm = require("wezterm")
local platform = require("utils.platform")
local font_size = platform().is_mac and 15 or 14

local function is_font_installed()
	local p = platform()
	if p.is_win then
		local success, stdout = wezterm.run_child_process({
			"powershell",
			"-NoProfile",
			"-Command",
			'[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null; '
				.. "(New-Object System.Drawing.Text.InstalledFontCollection).Families | "
				.. 'Where-Object { $_.Name -like "*JetBrains*" } | Select-Object -First 1',
		})
		return success and stdout ~= nil and stdout:gsub("%s+", "") ~= ""
	elseif p.is_mac then
		local success, stdout = wezterm.run_child_process({
			"bash",
			"-c",
			"ls ~/Library/Fonts/ /Library/Fonts/ 2>/dev/null | grep -i jetbrains",
		})
		return success and stdout ~= nil and stdout:gsub("%s+", "") ~= ""
	elseif p.is_linux then
		local success, stdout = wezterm.run_child_process({
			"bash",
			"-c",
			"fc-list | grep -i jetbrains",
		})
		return success and stdout ~= nil and stdout:gsub("%s+", "") ~= ""
	end
	return false
end

local function ensure_jetbrains_font()
	local p = platform()
	if p.is_win then
		wezterm.run_child_process({
			"powershell",
			"-NoProfile",
			"-Command",
			[[
                $url = "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
                $zip = "$env:TEMP\JetBrainsMono.zip"
                $dir = "$env:TEMP\JetBrainsMono"
                Invoke-WebRequest -Uri $url -OutFile $zip
                Expand-Archive -Path $zip -DestinationPath $dir -Force
                $fonts = (New-Object -ComObject Shell.Application).Namespace(0x14)
                Get-ChildItem "$dir" -Filter "JetBrainsMonoNLNerdFont-Regular.ttf" -Recurse | ForEach-Object {
                    $fonts.CopyHere($_.FullName, 0x10)
                }
            ]],
		})
	elseif p.is_mac then
		wezterm.run_child_process({
			"bash",
			"-c",
			"brew install --cask font-jetbrains-mono-nerd-font",
		})
	elseif p.is_linux then
		wezterm.run_child_process({
			"bash",
			"-c",
			[[
                mkdir -p ~/.local/share/fonts
                curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
                unzip -o /tmp/JetBrainsMono.zip "JetBrainsMonoNLNerdFont-Regular.ttf" -d ~/.local/share/fonts/
                fc-cache -fv
            ]],
		})
	end
end

wezterm.on("gui-startup", function()
	if not is_font_installed() then
		ensure_jetbrains_font()
	end
end)

return {
	font = wezterm.font_with_fallback({
		"JetBrainsMonoNL Nerd Font",
		"Consolas",
		"Monaco",
		"DejaVu Sans Mono",
		"Courier New",
	}),
	font_size = font_size,
	freetype_load_target = "Normal",
	freetype_render_target = "Normal",
}
