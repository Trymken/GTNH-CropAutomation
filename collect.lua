local component = require('component')
local action = require('action')
local robot = require('robot')
local sides = require('sides')
local database = require('database')
local gps = require('gps')
local config = require('config')
local scanner = require('scanner')
local events = require('events')
local spread = require('spread')
local inventory_controller = component.inventory_controller


local function findSeedCellStorage()
    for i = 1, config.storageFarmArea, 1 do
        gps.go(gps.storageSlotToPos(i))
        local crop = scanner.scan()
        if crop.name == 'emptyCrop' then
            action.harvest()
        end
        if crop.name ~= 'air' and crop.name ~= 'emptyCrop' and crop.isCrop then
            return i
        end
    end
    return -1
end


local function collectSeeds()
    local seedCell = 1
    local harvestedCrop = 1
    local isFirstRun = true

    while(true) do
        local slot = 1

        if action.needCharge() then
            action.charge()
        end

        seedCell = findSeedCellStorage()

        if (seedCell == -1) then
            return true
        end

        isFirstRun = true

        while slot <= config.storageFarmArea do

            if isFirstRun then
                slot = seedCell
                isFirstRun = false
            end

            if events.needExit() then
                print('autoCollect: Received Exit Command!')
                return false
            end

            os.sleep(0)

            gps.go(gps.storageSlotToPos(slot))
            local crop = scanner.scan()
            if crop.isCrop and crop.name ~= 'air' and crop.size >= (crop.max - 1) then
                action.harvest()
                harvestedCrop = harvestedCrop + 1
            end

            if harvestedCrop % (config.maxHarvests + 1) == 0 then
                action.dumpInventory()
                harvestedCrop = 1
            end

            if action.needCharge() then
                action.charge()
            end

            slot = slot + 1
        end
    end
end


local function collectMain(args)
    if args[1] == nil or tonumber(args[1], 10) == nil then
        args[1] = 1
    end

    print(string.format('Collect count: %d', args[1]))

    for i = 1, args[1], 1 do
        print(string.format("Current step: %d", i))
        spread.spreadMain(true, false)
        if (not collectSeeds()) then
            break
        end
    end

    events.unhookEvents()
    print('Collect complete!')
end


local function collectOnce()
    action.initWork()
    collectSeeds()
    action.dumpInventory()
    action.charge()
    print("Collect complete!")
    events.unhookEvents()
end


return {
    findSeedCellStorage = findSeedCellStorage,
    collectSeeds = collectSeeds,
    collectMain = collectMain,
    collectOnce = collectOnce
}