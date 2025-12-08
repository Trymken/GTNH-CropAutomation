local seeds = require('seeds')
local events = require('events')
local action = require('action')
local scanner = require('scanner')
local config = require('config')
local database = require('database')
local gps = require('gps')
local stat = require('stat')

local args = {...}


local function checkChild(slot, crop, targetCrop)
    if crop.isCrop and crop.name ~= 'emptyCrop' then

        if crop.name == 'air' then
            action.placeCropStick(2)

        elseif scanner.isWeed(crop, 'working') then
            action.deweed()
            action.placeCropStick()

        elseif crop.name == seeds.getSeedName(targetCrop) then

            if seeds.isEnoughStats(crop) then
                action.transplant(gps.workingSlotToPos(slot), gps.go(config.targetCropPos))
                action.placeCropStick(2)
                return true

            else
                action.deweed()
                action.placeCropStick()
            end

        else
            action.deweed()
            action.placeCropStick()
        end
    end

    return false
end


local function checkParent(slot, crop)
    if crop.isCrop and crop.name ~= 'air' and crop.name ~= 'emptyCrop' then
        if scanner.isWeed(crop, 'working') then
            action.deweed()
            database.updateFarm(slot, {isCrop=true, name='emptyCrop'})
        end
    end
end


local function findSeed(targetCrop)
    local isFound = false
    while (not isFound) do
    
        for slot=1, config.workingFarmArea, 1 do
            if events.needExit() then
                print('autoFind: Received Exit Command!')
                return false
            end

            gps.go(gps.workingSlotToPos(slot))
            local crop = scanner.scan()

            if slot % 2 == 0 then
                if checkChild(slot, crop, targetCrop) then
                    isFound = true
                    break
                end
            else
                checkParent(slot, crop)
            end

            if action.needCharge() then
                action.charge()
            end

        end

    end
end


local function main(args)
    if seeds.isCorrectSeed(args[1]) then
        action.initWork()
        print(string.format('autoFind: Target seed %s', args[1]))
        findSeed(args[1])
        stat.statMain(true, false)
    else
        print(string.format('Incorrect seed %s, maybe you made a typo', args[1]))
    end

    events.unhookEvents()
    print('autoFind: Complete!')
end


main(args)