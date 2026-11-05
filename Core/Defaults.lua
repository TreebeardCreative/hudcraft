local _, addon = ...

addon.Defaults = {
    Account = {
        version = 1,
        general = {
            showGroupName = true,
            spacing = 12,
            groupDirection = "row",
        },
    },
    Character = {
        windowPositions = {},
        windowCollapsed = {},
        windowSizes = {},
        frameHeaderPositions = {},
        lastSettingsPage = "home",
    },
}
