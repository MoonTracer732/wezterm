local wezterm = require("wezterm")
local platform = require("utils.platform")
local font_size = platform().is_mac and 15 or 14

-- 检查字体是否存在，不存在则下载
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
                Get-ChildItem "$dir\*NL*" -Include "*.ttf","*.otf" | ForEach-Object {
                    $fonts.CopyHere($_.FullName, 0x10)
                }
            ]],
		})
	elseif p.is_mac then
		wezterm.run_child_process({
			"bash",
			"-c",
			"brew tap homebrew/cask-fonts && brew install --cask font-jetbrains-mono-nerd-font",
		})
	elseif p.is_linux then
		wezterm.run_child_process({
			"bash",
			"-c",
			[[
                mkdir -p ~/.local/share/fonts
                curl -Lo /tmp/JetBrainsMono.zip "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip"
                unzip -o /tmp/JetBrainsMono.zip "*NL*" -d ~/.local/share/fonts/
                fc-cache -fv
            ]],
		})
	end
end

ensure_jetbrains_font()

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
