local _, addon = ...

addon.Modules = addon.Modules or {}
addon.Modules[#addon.Modules + 1] = {
    id = "bags",
    label = "Bags",
    updateEvents = { "BAG_UPDATE_DELAYED", "PLAYER_ENTERING_WORLD" },
    getText = function()
        local free, total = 0, 0
        local lastBag = NUM_BAG_SLOTS or 4
        if (NUM_REAGENTBAG_SLOTS or 0) > 0 then lastBag = lastBag + 1 end
        for bag = 0, lastBag do
            local slots = C_Container.GetContainerNumSlots(bag) or 0
            local available = C_Container.GetContainerNumFreeSlots(bag) or 0
            total = total + slots
            free = free + available
        end
        return string.format("Bags %d/%d free", free, total)
    end,
}
