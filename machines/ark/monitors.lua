-- =========================================================
-- ARK — Monitor configuration
-- =========================================================

hl.monitor({
    output = "eDP-1",
    mode = "1920x1080@60",
    position = "0x1920",
    scale = 1,
})

hl.monitor({
    output = "DP-1",
    mode = "1920x1080@60",
    position = "0x0",
    scale = 1,
})

-- =========================================================
-- Workspaces
-- =========================================================

hl.workspace_rule({
    workspace = "1",
    monitor = "eDP-1",
    default = true,
})

hl.workspace_rule({
    workspace = "2",
    monitor = "DP-1",
    default = true,
})
