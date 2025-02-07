#!/bin/bash

#EDIT THIS PATH TO REFLECT YOUR %Appdata%/Godot
settings_path=$(wslpath 'E:\AppData\Roaming\Godot')

#EDIT THIS TO MATCH YOUR VERSION SETTINGS FILE NAME
file_name='editor_settings-4.3.tres'

#EDIT THIS TO MATCH YOUR PATH TO SCRIPTS FOLDER
new_host=$(~/.scripts/wsl-ip.sh)


settings_file="${settings_path}/${file_name}"
echo "settings file: ${settings_file}"

temp_file='/tmp/godot-settings'

echo "setting network/language_server/remote_host = \"$new_host\""

sed -r "/language_server\/remote_host/s/\".*\"/\"$new_host\"/" "${settings_file}" > $temp_file

echo "overwriting original..."
cat $temp_file > "${settings_file}"
rm $temp_file
