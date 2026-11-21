-- Hyprland 0.57 decoration effects not owned by userprefs.lua.
hl.config({
    decoration = {
        wobble = { enabled = false },
    },
})

-- Backdrop blur for Veyra's translucent shell overlay (Island and panel surfaces).
hl.layer_rule({
    name = "veyra-shell-overlay-blur",
    match = { namespace = "^(veyra-shell-overlay|veyra-island-popup)$" },
    blur = true,
    blur_popups = true,
    ignore_alpha = 0.12,
})
