source /usr/share/cachyos-fish-config/cachyos-config.fish
# Append to ~/.config/fish/config.fish
# Persistent aliases belong in ~/.config/fish/functions; config.fish runs at
# every shell start, so define clear directly instead of `alias -s`, which
# rewrote clear.fish on every login and printed "funcsave: wrote ...".
function clear
    pyroclear $argv
end
# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

fish_add_path "$HOME/.spicetify"


# Added by Antigravity CLI installer
set -gx PATH "/home/andeomi/.local/bin" $PATH

if type -q starship
    starship init fish | source
end
