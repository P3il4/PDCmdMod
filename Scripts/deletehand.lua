local uim = require("uimanager")
local cm = require("commandmanager")


local cmd = cm.MANAGER:register(
    "deletehand",
    {
        description = "Deletes item in hand. Only works on droppable items.",
        args_syntax = nil,
        flags_syntax = nil
    },
    function(args, flags)
        local im = FindFirstOf("BP_InventoryManager_C")
        if not im or not im:IsValid() then
            print("[DeleteHand] InventoryManager not found")
            return true
        end

        -- Get the hand slot and container
        local handSlotOut = {}
        local handContainerOut = {}
        local ok, err = pcall(function()
            im:GetHandSlot(handSlotOut, handContainerOut)
        end)

        local handSlot = handSlotOut["Hand Slot"]
        local handContainer = handContainerOut["Hand Container"]

        print("[DeleteHand] Hand slot: " .. tostring(handSlot))
        print("[DeleteHand] Hand container: " .. tostring(handContainer))

        if not handSlot or not handSlot:IsValid() then
            print("[DeleteHand] No item in hand")
            return true
        end

        pcall(function() print("[DeleteHand] GetFullName: " .. handSlot:GetFullName()) end)
        pcall(function() print("[DeleteHand] ItemInstance: " .. tostring(handSlot.ItemInstance)) end)
        pcall(function() print("[DeleteHand] Instance: " .. tostring(handSlot.Instance)) end)
        pcall(function() print("[DeleteHand] Item: " .. tostring(handSlot.Item)) end)

        local instance = handSlot.ItemInstance
        local containerOut = {}
        pcall(function() im:GetItemInstanceContainer(instance, containerOut) end)
        local container = containerOut["ReturnValue"] or containerOut["Container"]
        print("[DeleteHand] Container: " .. tostring(container))


        -- Count world items before drop
        local before = FindAllOf("BP_WorldItem_C")
        local beforeCount = before and #before or 0

        -- Force dropping to be allowed
        pcall(function() im:SetItemDroppingAllowed(true) end)

        -- Now try dropping
        local dropSuccessOut = {}
        local worldActorOut = {}
        im:PlayerDropHandItem(dropSuccessOut, worldActorOut)
        print("[DeleteHand] Drop success: " .. tostring(dropSuccessOut["Drop Success"]))

        -- Restore normal drop rules
        -- pcall(function() im:SetItemDroppingAllowed(false) end)

        -- Find new world item
        local after = FindAllOf("BP_WorldItem_C")
        print("[DeleteHand] Before: " .. beforeCount .. " After: " .. (after and #after or 0))

        if after and #after > beforeCount then
            -- Find the new one
            local beforeSet = {}
            if before then
                for _, v in ipairs(before) do
                    local ok, name = pcall(function() return v:GetFullName() end)
                    if ok then beforeSet[name] = true end
                end
            end
            for _, v in ipairs(after) do
                local ok, name = pcall(function() return v:GetFullName() end)
                if ok and not beforeSet[name] then
                    print("[DeleteHand] New world item: " .. name)
                    pcall(function() v:K2_DestroyActor() end)
                    print("[DeleteHand] Destroyed!")
                    break
                end
            end
        end

        return true
    end
)