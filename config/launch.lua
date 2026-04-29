local platform = require('utils.platform')()

local options = {
   default_prog = {},
   launch_menu = {},
}

if platform.is_win then
   options.default_prog = { 'powershell' }
   options.launch_menu = {
      { label = 'PowerShell', args = { 'powershell' } },
      { label = 'Git Bash', args = { 'C:\\Program Files\\Git\\bin\\bash.exe', '-l' } },
      { label = 'CMD', args = { 'cmd' } },
      { label = 'Anaconda PowerShell', args = { 'powershell', '-ExecutionPolicy', 'ByPass', '-NoExit', '-Command', "& 'C:\\ProgramData\\miniconda3\\shell\\condabin\\conda-hook.ps1' ; conda activate 'C:\\ProgramData\\miniconda3'" } },
   }
elseif platform.is_mac then
   options.default_prog = { 'bash', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { '/opt/homebrew/bin/fish', '-l' } },
      { label = 'Nushell', args = { '/opt/homebrew/bin/nu', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
elseif platform.is_linux then
   options.default_prog = { 'bash', '-l' }
   options.launch_menu = {
      { label = 'Bash', args = { 'bash', '-l' } },
      { label = 'Fish', args = { 'fish', '-l' } },
      { label = 'Zsh', args = { 'zsh', '-l' } },
   }
end

return options
