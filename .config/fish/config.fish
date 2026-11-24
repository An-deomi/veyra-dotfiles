if test -f /usr/share/cachyos-fish-config/cachyos-config.fish
    source /usr/share/cachyos-fish-config/cachyos-config.fish
end

# Persistent aliases belong in ~/.config/fish/functions; config.fish runs at
# every shell start, so define clear directly instead of `alias -s`, which
# rewrote clear.fish on every login and printed "funcsave: wrote ...".
function clear
    if type -q pyroclear
        pyroclear $argv
    else
        command clear $argv
    end
end

fish_add_path "$HOME/.local/bin" "$HOME/.cargo/bin" "$HOME/.spicetify"

if type -q starship
    starship init fish | source
end
