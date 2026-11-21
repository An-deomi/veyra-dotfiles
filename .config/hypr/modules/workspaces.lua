-- Workspace placement is intentionally monitor-agnostic by default.
-- Set VEYRA_PRIMARY_MONITOR in your session environment to pin these workspaces
-- to a named output (for example: DP-1). Leave it unset for automatic placement.
local userPrefs = require("local_prefs")
local primaryMonitor = userPrefs.primary_monitor or os.getenv("VEYRA_PRIMARY_MONITOR")

local gamingRule = {
    workspace = "name:gaming",
    default = true,
}
if primaryMonitor and primaryMonitor ~= "" then
    gamingRule.monitor = primaryMonitor
end
hl.workspace_rule(gamingRule)

for workspace = 1, 3 do
    local rule = {
        workspace = tostring(workspace),
        default = true,
        persistent = true,
    }
    if primaryMonitor and primaryMonitor ~= "" then
        rule.monitor = primaryMonitor
    end
    hl.workspace_rule(rule)
end
