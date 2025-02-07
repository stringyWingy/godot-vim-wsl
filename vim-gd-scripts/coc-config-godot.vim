"automatically sets the host ip for the godot server
let g:wsl_ip = trim(system("~/.scripts/wsl-ip.sh"))
call coc#config("languageserver", {
              \"godot": {
              \"host": wsl_ip,
              \"filetypes": ["gdscript"],
              \"port": 6005
              \}})
