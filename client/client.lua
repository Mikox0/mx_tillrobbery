local robbedRegisters = {}

local function isRegisterRobbed(register)
    for _, robbed in ipairs(robbedRegisters) do
        if robbed == register then
            return true
        end
    end
    return false
end

local function addRobbedRegister(register)
    table.insert(robbedRegisters, register)
end

local function teleportPlayerToRegister(register)
    local ped = PlayerPedId()
    local registerCoords = GetEntityCoords(register)
    local registerHeading = GetEntityHeading(register)
    
    -- Oblicz offset - 0.8m przed kasą w kierunku jej rotacji
    local offsetDistance = 0.85
    local radians = math.rad(registerHeading)
    
    -- Oblicz pozycję gracza naprzeciwko kasy
    local playerX = registerCoords.x + (math.sin(radians) * offsetDistance)
    local playerY = registerCoords.y - (math.cos(radians) * offsetDistance)
    local playerZ = registerCoords.z - 1.0
    
    -- Teleportuj gracza i ustaw rotację twarzą do kasy
    SetEntityCoords(ped, playerX, playerY, playerZ, false, false, false, false)
    SetEntityHeading(ped, registerHeading)
end

local function spawnMoneyPropsAsync(register, callback)
    CreateThread(function()
        Wait(1000)

        local registerCoords2 = GetEntityCoords(register)
        local registerHeading2 = GetEntityHeading(register)
        local registerRot2 = GetEntityRotation(register)
        
        -- Model pieniędzy
        local moneyModel = `p_cs_dollarbillstack01x`
        
        RequestModel(moneyModel)
        while not HasModelLoaded(moneyModel) do
            Wait(10)
        end
        
        -- Oblicz pozycję pieniędzy w szufladzie
        local offsetDistance2 = 0.45
        local offsetHeight2 = 0.07
        local radians2 = math.rad(registerHeading2)
        
        -- Środkowa pozycja
        local centerX = registerCoords2.x + (math.sin(radians2) * offsetDistance2)
        local centerY = registerCoords2.y - (math.cos(radians2) * offsetDistance2)
        local centerZ = registerCoords2.z + offsetHeight2
        
        -- Oblicz offset na boki (lewo/prawo względem rotacji kasy)
        local sideOffset = 0.07 -- Odległość między propami
        local sideRadians = math.rad(registerHeading2 + 90) -- Kierunek prostopadły
        
        -- Pozycja pierwszego propa (lewo)
        local money1X = centerX + (math.sin(sideRadians) * sideOffset)
        local money1Y = centerY - (math.cos(sideRadians) * sideOffset)
        
        -- Pozycja drugiego propa (prawo)
        local money2X = centerX - (math.sin(sideRadians) * sideOffset)
        local money2Y = centerY + (math.cos(sideRadians) * sideOffset)
        
        -- Stwórz pierwszy prop pieniędzy
        local moneyProp1 = CreateObject(moneyModel, money1X, money1Y, centerZ, false, false, false)
        SetEntityRotation(moneyProp1, registerRot2.x, registerRot2.y, registerHeading2, 2, true)
        FreezeEntityPosition(moneyProp1, true)
        
        -- Stwórz drugi prop pieniędzy
        local moneyProp2 = CreateObject(moneyModel, money2X, money2Y, centerZ, false, false, false)
        SetEntityRotation(moneyProp2, registerRot2.x, registerRot2.y, registerHeading2, 2, true)
        FreezeEntityPosition(moneyProp2, true)
        
        SetModelAsNoLongerNeeded(moneyModel)
        
        -- Wywołaj callback z propami
        if callback then
            callback({moneyProp1, moneyProp2})
        end
    end)
end

local function getClosestRegister(coords)
    local registerModels = {
        `p_register01x`,
        `p_register03x`,
        `p_register04x`,
        `p_register05x`,
        `p_register06x`,
        `p_register07x`,
        `p_register08x`
    }
    
    for _, model in ipairs(registerModels) do
        local register = GetClosestObjectOfType(coords.x, coords.y, coords.z, 2.5, model, false, false, false)
        if register ~= 0 then
            return register
        end
    end
    
    return 0
end

exports.ox_target:addModel({
    'p_register01x',
    'p_register03x',
    'p_register04x',
    'p_register05x',
    'p_register06x',
    'p_register07x',
    'p_register08x',
    },{
    {
        name = 'rob_register',
        icon = 'fas fa-money-bill',
        label = 'Obrabuj kasę',
        onSelect = function(data)
            local entity = data.entity
            
            if isRegisterRobbed(entity) then
                lib.notify({
                    title = 'Kasa pusta',
                    description = 'Ta kasa została już obrabowana',
                    type = 'error'
                })
                return
            end

            TriggerEvent('rsg-lockpick:client:openLockpick', function(success)
                if success then
                    print('Lockpick: success!')

                    Wait(1000)
                    
                    local ped = PlayerPedId()
                    local coords = GetEntityCoords(ped)
                    local register = getClosestRegister(coords)
                    --print(register)

                    local moneyProps = nil

                    if register ~= 0 then
                        -- Teleportuj gracza przed kasą
                        teleportPlayerToRegister(register)
                        
                        RequestAnimDict("mech_pickup@loot@cash_register@open")
                        while not HasAnimDictLoaded("mech_pickup@loot@cash_register@open") do
                            Wait(10)
                        end
                        RequestAnimDict("mech_pickup@loot@cash_register@open_grab")
                        while not HasAnimDictLoaded("mech_pickup@loot@cash_register@open_grab") do
                            Wait(10)
                        end
                        
                        -- Spawn pieniędzy asynchronicznie
                        spawnMoneyPropsAsync(register, function(props)
                            moneyProps = props
                        end)

                        PlayEntityAnim(register, 'enter_short_reg', 'mech_pickup@loot@cash_register@open', 1000.0, false, true, false, 0, 0)
                    end

                    if lib.progressBar({
                        duration = 5000,
                        label = 'Okradanie kasy fiskalnej...',
                        useWhileDead = false,
                        canCancel = true,
                        disable = {
                            move = true,
                        },
                        anim = {
                            dict = 'mech_pickup@loot@cash_register@open_grab',
                            clip = 'enter_openoxxo'
                        },
                    }) then
                        TriggerServerEvent('register:robbery', entity)
                        addRobbedRegister(entity)
                    end

                    -- Usuń propy pieniędzy
                    if moneyProps ~= nil then
                        for _, prop in ipairs(moneyProps) do
                            if DoesEntityExist(prop) then
                                DeleteObject(prop)
                            end
                        end
                    end
                    
                    Wait(5000)
                    
                    StopEntityAnim(register, 'enter_short_reg', 'mech_pickup@loot@cash_register@open')
                    RemoveAnimDict("mech_pickup@loot@cash_register@open")
                    RemoveAnimDict("mech_pickup@loot@cash_register@open_grab")
                else
                    print('Lockpick: failed.')
                end
            end)
        end,
        canInteract = function(entity)
            return not isRegisterRobbed(entity)
        end
    }
})