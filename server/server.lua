local RSGCore = exports['rsg-core']:GetCoreObject()

RegisterNetEvent('register:robbery', function(register)
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local float = math.random()
    local bloodReward = float * (Config.RewardMax - 10) + Config.RewardMin
    bloodReward = math.floor(bloodReward * 100) / 100

    if Player.Functions.AddMoney('bloodmoney', bloodReward, 'store-robbery') then
        if Config.Notify == "OX" then
            TriggerClientEvent('ox_lib:notify', source, {
                title = 'Sukces',
                description = 'Ukradłeś $' .. bloodReward .. ' brudnej gotówki!',
                type = 'success'
            })
        elseif Config.Notify == "BLN" then
            TriggerClientEvent("bln_notify:send", source, {
                title = "Ukradłeś $" .. bloodReward .. " ~red~brudnej gotówki~e~!"
            }, "TIP_CASH")
        end
    end
end)