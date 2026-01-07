local active = false
local targetId = ""
local lastExecution = 0
local EXECUTION_DELAY = 3000

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    sampAddChatMessage("{ff0000}[INFO] {ffffff}Auto Find script loaded. Command: /afind | Author: LUA MODS", -1)

    sampRegisterChatCommand("afind", function(arg)
        if arg and #arg > 0 then
            local id = tonumber(arg:match("%d+"))
            if not id then
                sampAddChatMessage("{ff0000}[Auto Find] {ffffff}Error: ID must be a number!", -1)
                return
            end
            
            if id < 0 or id > 1000 then
                sampAddChatMessage("{ff0000}[Auto Find] {ffffff}Error: Invalid player ID (0-1000)!", -1)
                return
            end
            
            targetId = tostring(id)
            active = not active
            
            local status = active and "{00ff00}ACTIVE" or "{ff0000}INACTIVE"
            sampAddChatMessage("{ff0000}[Auto Find] {ffffff}Status: " .. status .. " | Target ID: " .. targetId, -1)
        else
            sampAddChatMessage("{ff0000}[Auto Find] {ffffff}Usage: /afind [player ID]", -1)
            sampAddChatMessage("{ff0000}[Auto Find] {ffffff}Current: " .. (active and "{00ff00}ON" or "{ff0000}OFF") .. " | Target: " .. (targetId ~= "" and targetId or "none"), -1)
        end
    end)

    while true do
        wait(0)
        
        if active and targetId ~= "" then
            local currentTime = os.clock() * 1000
            
            if currentTime - lastExecution >= EXECUTION_DELAY then
                lastExecution = currentTime
                
                local isConnected = pcall(function() 
                    return sampIsPlayerConnected(tonumber(targetId)) 
                end)
                
                if not isConnected then
                    sampAddChatMessage("{ff0000}[Auto Find] {ffffff}Player " .. targetId .. " disconnected!", -1)
                    active = false
                else
                    pcall(function()
                        sampSendChat("/find " .. targetId)
                    end)
                end
            end
        end
    end
end