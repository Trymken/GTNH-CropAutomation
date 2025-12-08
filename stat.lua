local action = require('action')
local database = require('database')
local gps = require('gps')
local scanner = require('scanner')
local config = require('config')
local events = require('events')

-- ===================== FUNCTIONS ======================

local function updateLowest(variables)
    local farm = database.getFarm()
    variables.lowestStat = 99
    variables.lowestStatSlot = 0

    -- Find lowest stat slot
    for slot=1, config.workingFarmArea, 2 do
        local crop = farm[slot]
        if crop.isCrop then

            if crop.name == 'air' or crop.name == 'emptyCrop' then
                variables.lowestStat = 0
                variables.lowestStatSlot = slot
                break

            elseif crop.name ~= variables.targetCrop then
                local stat = crop.gr + crop.ga - crop.re - 2
                if stat < variables.lowestStat then
                    variables.lowestStat = stat
                    variables.lowestStatSlot = slot
                end

            else
                local stat = crop.gr + crop.ga - crop.re
                if stat < variables.lowestStat then
                    variables.lowestStat = stat
                    variables.lowestStatSlot = slot
                end
            end
        end
    end
end


local function checkChild(slot, crop, firstRun, variables)
    if crop.isCrop and crop.name ~= 'emptyCrop' then

        if crop.name == 'air' then
            action.placeCropStick(2)

        elseif scanner.isWeed(crop, 'working') then
            action.deweed()
            action.placeCropStick()

        elseif firstRun then
            return

        elseif crop.name == variables.targetCrop then
            local stat = crop.gr + crop.ga - crop.re

            if stat > variables.lowestStat then
                action.transplant(gps.workingSlotToPos(slot), gps.workingSlotToPos(variables.lowestStatSlot))
                action.placeCropStick(2)
                database.updateFarm(variables.lowestStatSlot, crop)
                updateLowest(variables)

            else
                action.deweed()
                action.placeCropStick()
            end

        elseif config.keepMutations and (not database.existInStorage(crop)) then
            action.transplant(gps.workingSlotToPos(slot), gps.storageSlotToPos(database.nextStorageSlot()))
            action.placeCropStick(2)
            database.addToStorage(crop)

        else
            action.deweed()
            action.placeCropStick()
        end
    end
end


local function checkParent(slot, crop, firstRun, variables)
    if crop.isCrop and crop.name ~= 'air' and crop.name ~= 'emptyCrop' then
        if scanner.isWeed(crop, 'working') then
            action.deweed()
            database.updateFarm(slot, {isCrop=true, name='emptyCrop'})
            if not firstRun then
                updateLowest()
            end
        end
    end
end

-- ====================== THE LOOP ======================

local function statOnce(firstRun, variables)
    for slot=1, config.workingFarmArea, 1 do

        -- Terminal Condition
        if #database.getStorage() >= config.storageFarmArea then
            print('autoStat: Storage Full!')
            return false
        end

        -- Terminal Condition
        if variables.lowestStat >= config.autoStatThreshold then
            print('autoStat: Minimum Stat Threshold Reached!')
            return false
        end

        -- Terminal Condition
        if events.needExit() then
            print('autoStat: Received Exit Command!')
            return false
        end

        os.sleep(0)

        -- Scan
        gps.go(gps.workingSlotToPos(slot))
        local crop = scanner.scan()

        if firstRun then
            database.updateFarm(slot, crop)
            if slot == 1 then
                variables.targetCrop = database.getFarm()[1].name
                print(string.format('autoStat: Target %s', variables.targetCrop))
            end
        end

        if slot % 2 == 0 then
            checkChild(slot, crop, firstRun, variables)
        else
            checkParent(slot, crop, firstRun, variables)
        end

        if action.needCharge() then
            action.charge()
        end
    end
    return true
end

-- ======================== MAIN ========================

local function statMain(init, unhook)
    local variables = {
        lowestStat = 0,
        lowestStatSlot = 0,
        targetCrop = ''
    }

    if init then
        action.initWork()
    end
    print('autoStat: Scanning Farm')

    -- First Run
    statOnce(true, variables)
    action.restockAll()
    updateLowest(variables)

    -- Loop
    while statOnce(false, variables) do
        action.restockAll()
        
    end

    -- Terminated Early
    if events.needExit() then
        action.restockAll()
    end

    -- Finish
    if config.cleanUp then
        action.cleanUp()
        action.restockAll()
    end

    if unhook then
        events.unhookEvents()
    end
    print('autoStat: Complete!')
end



return {
    statMain = statMain
}