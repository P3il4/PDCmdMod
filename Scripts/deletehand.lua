local uim = require("uimanager")
local cm = require("commandmanager")
local give = require("give")

cm.MANAGER:register(
    "duplicatehand",
    {
        description = "Duplicate the item currently in hand.",
        args_syntax = "[count]"
    },
    function(args, flags)
        local im = FindFirstOf("BP_InventoryManager_C")
        if not im or not im:IsValid() then
            uim.sendMessage("Duplicate", "InventoryManager not found", uim.MessageTypes.ERR)
            return true
        end

        local handSlotOut = {}
        local handContainerOut = {}
        im:GetHandSlot(handSlotOut, handContainerOut)

        local handSlot = handSlotOut["Hand Slot"]
        if not handSlot or not handSlot:IsValid() then
            uim.sendMessage("Duplicate", "Nothing in hand", uim.MessageTypes.ALERT)
            return true
        end

        local count = tonumber(args[1]) or 1

        -- Snapshot des WorldItems avant le drop
        local before = FindAllOf("BP_WorldItem_C")
        local beforeSet = {}
        if before then
            for _, v in ipairs(before) do
                local ok, name = pcall(function() return v:GetFullName() end)
                if ok then beforeSet[name] = true end
            end
        end

        -- Trouver le nouveau WorldItem
        local after = FindAllOf("BP_WorldItem_C")
        local newWorldItem = nil
        if after then
            for _, v in ipairs(after) do
                local ok, name = pcall(function() return v:GetFullName() end)
                if ok and not beforeSet[name] then
                    newWorldItem = v
                    break
                end
            end
        end

        if not newWorldItem then
            uim.sendMessage("Duplicate", "Could not find dropped WorldItem", uim.MessageTypes.ERR)
            return true
        end

        -- Lire l'archétype depuis le WorldItem
        local arch = nil
        pcall(function()
            local slot = newWorldItem.ItemSlot
            if slot and slot.ItemInstance and slot.ItemInstance.Archetype then
                arch = slot.ItemInstance.Archetype
            end
        end)
        if not arch then
            pcall(function()
                if newWorldItem.ItemInstance and newWorldItem.ItemInstance.Archetype then
                    arch = newWorldItem.ItemInstance.Archetype
                end
            end)
        end
        if not arch then
            pcall(function()
                arch = newWorldItem.Archetype
            end)
        end

        -- Détruire le WorldItem droppé
        pcall(function() newWorldItem:K2_DestroyActor() end)

        if not arch then
            uim.sendMessage("Duplicate", "Could not read archetype from WorldItem", uim.MessageTypes.ERR)
            return true
        end

        -- Donner count+1 (on a droppé l'original, donc on remet 1 + les copies)
        give.GiveArchetype(im, arch, count)

        return true
    end
)
