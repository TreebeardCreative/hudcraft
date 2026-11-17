local _, addon = ...

addon.Defaults = {
    Account = {
        version = 4,
        general = {
            showGroupName = true,
            spacing = 6,
            groupDirection = "row",
            groupFrameLayer = 3,
            fontSize = 14,
            groupHeaderPosition = "top",
            horizontalSeparator = "-",
            verticalSeparator = "",
            clockSource = "local",
        },
        groups = {
            initialized = false,
        nextId = 2,
            order = { 1 },
            byId = {
                [1] = {
                    id = 1,
                    name = "Main",
                    builtIn = true,
                    editable = true,
                    selectedModules = {
                        level = true,
                        experience = true,
                        bags = true,
                        clock = true,
                    },
                    moduleOrder = { "level", "experience", "bags", "clock" },
                    horizontalSeparator = "-",
                    verticalSeparator = "",
                    useGlobalStyle = true,
                },
            },
        },
        styles = {
            settings = "Warm Warcraft",
            groups = "Warm Warcraft",
            groupOverrides = {
                colors = {},
                opacity = {},
            },
        },
    },
    Character = {
        windowPositions = {},
        windowCollapsed = {},
        windowSizes = {},
        frameHeaderPositions = {},
        lastSettingsPage = "main",
        lastSettingsSubpage = "welcome",
        groupsEnabled = {},
        groupsLocked = {},
        moduleLabels = {},
        moduleSettings = {},
    },
}
