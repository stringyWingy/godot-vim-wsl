#!/bin/bash
unix_path=$(wslpath "$1")
vim --servername godot --remote "$unix_path"
