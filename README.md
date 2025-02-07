# Using WSL with Godot
author: Stringy Wingy

last edited: 02 07 2025

This repo contains scripts and notes about how I hooked up Godot 4.3 to a text
editor running inside an instance of WSL2 (Ubuntu 20.04)

At the time of this writing, although WSL2 comes with the ability to run
graphical linux applications, at least on my machine, the Godot linux
executable was extremely unhappy with that whole situation.

The text editor in question is Vim 9.0 using coc-nvim as the lsp client. I do a
lot of coding on my laptop running Linux Mint, and love the workflow using vim
and tmux, and wanted to find a solution that would enable that workflow on my
Windows desktop. Hopefully it helps you.

## Contents
1. [The Network / Firewall](#The-Network--Firewall)
2. [Getting The Host Ip](#Getting-The-Host-Ip)
3. [Setting Up Godot](#Setting-Up-Godot)
4. [Recompiling Vim With +clientserver](#Recompiling-Vim-With-clientserver)
5. [Opening Files in Vim From Godot](#Opening-Files-in-Vim-From-Godot)
6. [Connecting To Godot LSP From Coc](#Connecting-To-Godot-LSP-From-Coc)


---

## The Network / Firewall

Normally, you could leave Godot's language server settings as default, configure
your editor to look for the LSP on localhost:6005 and that's that. However,
WSL's "localhost" is NOT equivalent to the host machine's "localhost". When the
Godot LSP binds to a port on 127.0.0.1 on Windows, it will be inaccessible to WSL, because
its VM is considered a different machine connected to a different network
adapter.

After quite some digging, [I found this github
issue][https://github.com/microsoft/WSL/issues/4585#issuecomment-610061194]
regarding the quirks of the default settings of WSL's virtual network interface,
and this beautiful one-liner that solves the problem:

In Powershell, as administrator (search for Powershell in the start menu, right
click > "Run as administrator")

```
New-NetFirewallRule -DisplayName "WSL" -Direction Inbound  -InterfaceAlias
"vEthernet (WSL)" -Action Allow
```

This creates a firewall rule to allow all ""incoming" network traffic from the
WSL's network adapter, allowing it to make a TCP connection to the Windows
machine. I hope this saves you as much time as I wasted scratching my head about
this.

---

## Getting The Host Ip

You can find the ip of the WSL instance from either cmd or bash, using
`ipconfig` or `ip route` respectively. In ipconfig, you're looking for the entry
labeled "ethernet adapter vEthernet(WSL)". Creating a script to automatically
spit out this ip is pretty simple in bash:

```
#!/bin/bash
#~/vim-gd-scripts/wsl-ip.sh
echo $(ip route | grep default | awk '{print $3}')
```
In Godot's Editor Settings > Network > Language Server, this is what you'd want
to set as the "Remote Host" so that WSL can access it. It's also the ip address
you'd want to point your editor to. The tricky thing is that this ip changes
every time you reboot. 

---

## Setting Up Godot

The faster, lazier, and somewhat riskier solution is to set the language server
host to 0.0.0.0. This tells it to listen on all available network adapters,
which will expose it to potential connections from _actually_ outside your
machine. But it will allow WSL to connect to it.

I was already down the rabbit hole and wrote a script to automatically set the
ip in the Godot editor settings file

```
#!/bin/bash
#~/vim-gd-scripts/godot-auto-update-lsp-host.sh

#EDIT THIS PATH TO REFLECT YOUR %Appdata%/Godot
settings_path=$(wslpath 'E:\AppData\Roaming\Godot')

#EDIT THIS TO MATCH YOUR VERSION SETTINGS FILE NAME
file_name='editor_settings-4.3.tres'

#EDIT THIS TO MATCH YOUR PATH TO SCRIPTS FOLDER
new_host=$(~/vim-gd-scripts/wsl-ip.sh)


settings_file="${settings_path}/${file_name}"
echo "settings file: ${settings_file}"

temp_file='/tmp/godot-settings'

echo "setting network/language_server/remote_host = \"$new_host\""

sed -r "/language_server\/remote_host/s/\".*\"/\"$new_host\"/" "${settings_file}" > $temp_file

echo "overwriting original..."
cat $temp_file > "${settings_file}"
rm $temp_file
```

And on the Windows side of things, a batch file to run the above script before
launching Godot (once again, make sure the path to the script is correct for
your machine)

```
wsl -e /root/vim-gd-scripts/godot-auto-update-lsp-host.sh
Godot_v4.3-stable_win64.exe
```

wsl -e basically lets you "hop into" linux from the command line and execute a
command, which is great news for someone more familiar with bash than with the
Windows command line.

Save this as godot.bat or whatever, and put it in the same folder as your Godot
executable. You can make a desktop shortcut to it, and launch it instead of the
normal Godot shortcut to always automatically have the lsp set up correctly.

---

## Recompiling Vim With +clientserver
The version of Vim that came with the WSL Ubuntu distrobution had two problems
with it:
- it was old enough that it lacked some vimscript functions that coc-nvim
    expected to be able to call
- it didn't have clientserver compiled in

The clientserver feature is what allows Godot to run a command remotely in a vim
process running elsewhere. Namely, to tell vim to open up a .gd file when you
create one or double click one in the editor. You can check your vim's features
with

```
vim --version
```

If your version isn't >= 9, you might have issues with coc-nvim. If you don't
see `+clientserver` in the features list, you'll definitely need a binary that
has it. Some people online say to just `apt install vim-gtk`, and that might
work for you, but it didn't for me. Whenever you install a different version of
vim, be sure to `hash -r` to refresh which version gets called when you run the
vim command before re-checking `vim --version`.

The clientserver feature depends on some gui libraries, as it expects to be able
to use the Xserver for the client-server communication. In order to enable
source packages, you'll have to go to /etc/apt/sources.list and uncomment all
the deb-src lines. You can comment them back out later. Then run:

```
apt-get build-dep vim-gtk
```

Clone the [vim git repo][https://github.com/vim/vim]

Inside the directory,

```
make distclean
./configure --with-features=huge --enable-gui=gtk2
```

The console will spit out a ton of stuff. If you scroll back and see `checking
--enable-gui argument... no GUI support`, something's gone wrong. `make
distclean`, make sure you have the build dependincies, and configure it again.

Then,

```
make -j4
make install
```

To compile and install.

```
hash -r
vim --version
```

should give you +clientserver


---

## Opening Files in Vim From Godot
The godot docs do a decent job at explaining this, but it's a little more
complicated having to pass from Windows-world to linux-world. Trying to write
the whole console command in the Godot settings wasn't working out for me, so I
ended up with this bash script:

```
#!/bin/bash
#~/vim-gd-scripts/vim-godot-remote.sh
unix_path=$(wslpath "$1")
vim --servername godot --remote "$unix_path"
```

All this does is convert the windows-style filepath to a unix-style one, making
sure that any spaces in the filepaths get safety quotes, then try to remotely
open that file in a vim server named "godot". In order to create the vim server,
run

```
vim --servername godot
```

This will launch a normal vim session, but will listen to --remote commands to the
servername "godot"

[More info on vim remote][https://vimdoc.sourceforge.net/htmldoc/remote.html]

Then, in Godot:
Editor Settings > Text Editor > External:
>Use External Editor: On
>Exec Path: wsl
>Exec Flags: -e /root/vim-gd-scripts/vim-godot-remote.sh {file}

once again, using wsl -e to execute a command inside linux

{file} is a special tag that Godot will automatically fill whenever it wants to
open up a text file in the editor. For whatever reason, this excludes Godot's
shader language files.

**NOTE:** If Godot tries to open a file before a vim process with --servername
"godot" already exists, it will spawn one in the background. If you forget to
start vim before opening a file from Godot, use `killall vim` to kill the
background vim process and start a new vim with `--servername godot`

---

## Connecting To Godot LSP From Coc
My .vimrc includes the example coc .vimrc, tweaked to taste. [I'm not gonna
walk you through getting coc up and running.][https://github.com/neoclide/coc.nvim?tab=readme-ov-file]

Tell .vimrc to look out for .gd files by adding:

```
au BufRead,BufNewFile *.gd	set filetype=gdscript
```

As per the [coc
docs][https://github.com/neoclide/coc.nvim/wiki/Language-servers#godot], Adding
the following to the coc config will tell coc how to connect to the Godot lsp.
(`:CocConfig` from inside vim quickly opens the file). **NOTE:As of this
writing, the coc wiki entry on Godot has an outdated port number. Godot defaults
to 6005, not 6008.**

```
"languageserver": {
    "godot": {
      "host": "127.0.0.1",
      "filetypes": ["gdscript"],
      "port": 6005
    }
}
```

However, the "host" property will have to be set dynamically, which can be done
by calling coc#config() in a vimscript:

```
"automatically sets the host ip for the godot server
let g:wsl_ip = trim(system("~/vim-gd-scripts/wsl-ip.sh"))
call coc#config("languageserver", {
              \"godot": {
              \"host": wsl_ip,
              \"filetypes": ["gdscript"],
              \"port": 6005
              \}})
```

This can go right into your .vimrc, after any coc setup, or in a separate file
that gets sourced by .vimrc

```
"whatever other coc setup scripts go first
source ~/.vim/coc-settings.vim
"then dynamically set the godot server host
source ~/vim-gd-scripts/coc-config-godot.vim
```

With this script in place, it's probably best to take the "godot" section out of
the coc-config.json to avoid conflicts. Godot is currently the only lsp I use
that isn't configured as a coc extension, so I'm not sure how calling coc#config
affects other entires in "languageserver" section of the config.

---

## Conclusion
I've included all the scripts I used in this repo. My WSL acts as the root user
by default, with its home directory at /root. If that's the case for you, you
should be able to copy the vim-gd-scripts directory straight into your WSL's
home directory. If not, you'll have to tweak the paths to reflect wherever you
want to put the scripts. Either way, be sure to tweak the path to Godot's
AppData.

That should all have you up and running. If it doesn't, it should give you a
good sense of what needs to happen to get Godot and an editor in WSL talking.
Happy coding :)
