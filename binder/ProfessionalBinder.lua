local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local requests = require 'requests'

-- ==========================================================
-- ÊÎÍÔÈÃ È ÂÅÐÑÈß
-- ==========================================================
local script_version = "6.2"
local update_url = "https://github.com/luamods/lua_scripts/raw/refs/heads/main/binder/version.json" -- Ññûëêà íà ôàéë ñ âåðñèåé
local configPath = getWorkingDirectory() .. "\\config\\ProfessionalBinder.txt"

local renderWindow = imgui.new.bool(false)
local winState = imgui.new.bool(false)
local animAlpha = 0.0
local activeTab, targetTab, tabAlpha = 1, 1, 1.0
local binds = {}
local stopBinds = false 
local updateStatus = u8"Îáíîâëåíèÿ íå ïðîâåðÿëèñü"

local buf = {
    name = imgui.new.char[128](""),
    cmd = imgui.new.char[64](""),
    delayStart = imgui.new.float(1.0),
    delayBetween = imgui.new.float(5.0),
    text = imgui.new.char[4096]("")
}

-- ==========================================================
-- ÑÈÑÒÅÌÀ ÎÁÍÎÂËÅÍÈÉ
-- ==========================================================
function checkUpdates()
    updateStatus = u8"Ïðîâåðêà..."
    lua_thread.create(function()
        local status, response = pcall(requests.get, update_url)
        if status and response.status_code == 200 then
            local new_ver = response.text:gsub("%s+", "")
            if new_ver ~= script_version then
                updateStatus = u8"Äîñòóïíà íîâàÿ âåðñèÿ: " .. new_ver
            else
                updateStatus = u8"Ó âàñ ïîñëåäíÿÿ âåðñèÿ"
            end
        else
            updateStatus = u8"Îøèáêà ïîäêëþ÷åíèÿ ê ñåðâåðó"
        end
    end)
end

-- ==========================================================
-- ËÎÃÈÊÀ ÁÈÍÄÅÐÀ
-- ==========================================================
function lerp(a, b, t) return a + (b - a) * t end

function sendToSampChat(text, delayBetween)
    if not text or #text == 0 then return end
    stopBinds = false 
    lua_thread.create(function()
        for line in text:gmatch("[^\r\n]+") do
            if stopBinds then break end 
            local cleanLine = line:gsub("^%s*(.-)%s*$", "%1")
            if #cleanLine > 0 then
                local status, result = pcall(function() return u8:decode(cleanLine) end)
                sampSendChat(status and result or cleanLine)
                wait(tonumber(delayBetween)) 
            end
        end
        if stopBinds then sampAddChatMessage("{FF0000}[Binder] {FFFFFF}Îñòàíîâëåíî!", -1) end
    end)
end

function saveBinds()
    if not doesDirectoryExist(getWorkingDirectory() .. "\\config") then createDirectory(getWorkingDirectory() .. "\\config") end
    local f = io.open(configPath, "w")
    if f then
        for _, b in ipairs(binds) do
            local safeText = b.text:gsub("\n", "\\n"):gsub("\r", "")
            f:write(string.format("%s|%s|%d|%d|%s\n", b.cmd, safeText, b.delayStart, b.delayBetween, b.name))
        end
        f:close()
    end
end

function registerBind(b)
    sampRegisterChatCommand(b.cmd, function()
        lua_thread.create(function()
            wait(tonumber(b.delayStart))
            if not stopBinds then sendToSampChat(b.text, b.delayBetween) end
        end)
    end)
end

function loadBinds()
    binds = {}
    if doesFileExist(configPath) then
        local f = io.open(configPath, "r")
        if f then
            for line in f:lines() do
                local cmd, txt, dStart, dBetween, name = line:match("^(.-)|(.-)|(%d+)|(%d+)|(.-)$")
                if cmd then 
                    local b = {cmd = cmd, text = txt:gsub("\\n", "\n"), delayStart = tonumber(dStart), delayBetween = tonumber(dBetween), name = name}
                    table.insert(binds, b); registerBind(b)
                end
            end
            f:close()
        end
    end
end

-- ==========================================================
-- ÈÍÒÅÐÔÅÉÑ
-- ==========================================================
imgui.OnInitialize(function()
    loadBinds()
    local style = imgui.GetStyle()
    style.WindowRounding, style.ChildRounding = 12, 10
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(0.07, 0.08, 0.11, 1.00)
    style.Colors[imgui.Col.ChildBg]  = imgui.ImVec4(0.11, 0.12, 0.16, 1.00)
    style.Colors[imgui.Col.Button]   = imgui.ImVec4(0.16, 0.18, 0.25, 1.00)
end)

imgui.OnFrame(function() return renderWindow[0] end, function()
    local dt = imgui.GetIO().DeltaTime
    animAlpha = lerp(animAlpha, winState[0] and 1.0 or 0.0, dt * 10.0)
    if animAlpha < 0.01 and not winState[0] then renderWindow[0] = false end

    if activeTab ~= targetTab then
        tabAlpha = lerp(tabAlpha, 0.0, dt * 15.0)
        if tabAlpha < 0.05 then activeTab = targetTab end
    else
        tabAlpha = lerp(tabAlpha, 1.0, dt * 10.0)
    end

    imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, animAlpha)
    imgui.SetNextWindowSize(imgui.ImVec2(800, 550), imgui.Cond.Always)
    
    if imgui.Begin("##BinderUI", winState, imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.NoResize) then
        local p, s = imgui.GetWindowPos(), imgui.GetWindowSize()
        local dl = imgui.GetWindowDrawList()
        dl:AddRectFilled(p, imgui.ImVec2(p.x + s.x, p.y + 55), imgui.GetColorU32(imgui.Col.ChildBg), 12, 3)
        imgui.SetCursorPos(imgui.ImVec2(25, 18)); imgui.TextColored(imgui.ImVec4(0.22, 0.42, 0.90, 1.0), "PROFESSIONAL BINDER | v" .. script_version)
        
        imgui.SetCursorPos(imgui.ImVec2(s.x - 45, 12))
        if imgui.Button("X##cls", imgui.ImVec2(32, 32)) then winState[0] = false end

        imgui.SetCursorPos(imgui.ImVec2(12, 70))
        imgui.BeginChild("Navbar", imgui.ImVec2(185, -12), true)
            if imgui.Selectable(u8" > Ãëàâíàÿ", targetTab == 1, 0, imgui.ImVec2(0, 40)) then targetTab = 1 end
            if imgui.Selectable(u8" > Ìîè áèíäû", targetTab == 2, 0, imgui.ImVec2(0, 40)) then targetTab = 2 end
            if imgui.Selectable(u8" > Ñîçäàòü", targetTab == 3, 0, imgui.ImVec2(0, 40)) then targetTab = 3 end
            if imgui.Selectable(u8" > Èíôîðìàöèÿ", targetTab == 4, 0, imgui.ImVec2(0, 40)) then targetTab = 4 end
            
            imgui.SetCursorPosY(imgui.GetWindowHeight() - 60)
            imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.1, 0.1, 1.0))
            if imgui.Button(u8"ÑÒÎÏ (F9)", imgui.ImVec2(-1, 40)) then stopBinds = true end
            imgui.PopStyleColor()
        imgui.EndChild()

        imgui.SameLine(); imgui.SetCursorPosY(70)
        imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, animAlpha * tabAlpha)
        imgui.BeginChild("MainArea", imgui.ImVec2(-12, -12), true)
            
            if activeTab == 1 then
                imgui.Text(u8"Äîáðî ïîæàëîâàòü â Professional Binder!"); imgui.Separator()
                imgui.TextWrapped(u8"Èñïîëüçóéòå ëåâîå ìåíþ äëÿ íàâèãàöèè.\nF9 — ýêñòðåííàÿ îñòàíîâêà âñåõ áèíäîâ.")
            
            elseif activeTab == 2 then
                for i, b in ipairs(binds) do
                    imgui.BeginChild("b"..i, imgui.ImVec2(-1, 110), true)
                        imgui.Text(u8(b.name) .. " [/" .. b.cmd .. "]")
                        imgui.TextDisabled(u8"Çàäåðæêà: " .. string.format("%.1f", b.delayBetween/1000) .. u8" ñåê.")
                        imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth() - 380, 55))
                        if imgui.Button(u8"Çàïóñòèòü##"..i, imgui.ImVec2(85, 30)) then sendToSampChat(b.text, b.delayBetween) end
                        imgui.SameLine()
                        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.6, 0.1, 0.1, 1.0))
                        if imgui.Button(u8"ÑÒÎÏ##"..i, imgui.ImVec2(85, 30)) then stopBinds = true end
                        imgui.PopStyleColor()
                        imgui.SameLine()
                        if imgui.Button(u8"Èçìåíèòü##"..i, imgui.ImVec2(90, 30)) then
                            ffi.copy(buf.name, b.name); ffi.copy(buf.cmd, b.cmd); ffi.copy(buf.text, b.text)
                            buf.delayStart[0] = b.delayStart/1000; buf.delayBetween[0] = b.delayBetween/1000
                            table.remove(binds, i); targetTab = 3
                        end
                        imgui.SameLine()
                        if imgui.Button(u8"Óäàëèòü##"..i, imgui.ImVec2(85, 30)) then table.remove(binds, i); saveBinds() end
                    imgui.EndChild(); imgui.Spacing()
                end

            elseif activeTab == 3 then
                imgui.Text(u8"Ðåäàêòîð"); imgui.Separator()
                imgui.Text(u8"Íàçâàíèå:"); imgui.InputText("##n", buf.name, 128)
                imgui.Text(u8"Êîìàíäà:"); imgui.InputText("##c", buf.cmd, 64)
                imgui.Text(u8"Çàäåðæêà (ñåê):")
                imgui.SliderFloat("##db", buf.delayBetween, 1.0, 10.0, "%.1f") 
                imgui.Text(u8"Òåêñò:")
                imgui.InputTextMultiline("##t", buf.text, 4096, imgui.ImVec2(-1, 150))
                if imgui.Button(u8"ÑÎÕÐÀÍÈÒÜ", imgui.ImVec2(-1, 45)) then
                    local c, t, n = ffi.string(buf.cmd), ffi.string(buf.text), ffi.string(buf.name)
                    if #c > 0 and #t > 0 then
                        local newB = {cmd = c, text = t, name = n, delayStart = 1000, delayBetween = math.floor(buf.delayBetween[0]*1000)}
                        table.insert(binds, newB); saveBinds(); registerBind(newB); targetTab = 2
                    end
                end

            elseif activeTab == 4 then
                imgui.Text(u8"Èíôîðìàöèÿ"); imgui.Separator()
                imgui.Text(u8"Âåðñèÿ ñêðèïòà: " .. script_version)
                imgui.Text(u8"Ñòàòóñ: " .. updateStatus)
                if imgui.Button(u8"Ïðîâåðèòü îáíîâëåíèÿ", imgui.ImVec2(-1, 40)) then checkUpdates() end
                imgui.Spacing(); imgui.Separator(); imgui.Text("(c) LUA MODS 2026")
            end
        imgui.EndChild()
        imgui.PopStyleVar(); imgui.End()
    end
    imgui.PopStyleVar()
end)

function main()
    while not isSampAvailable() do wait(100) end
    sampRegisterChatCommand("bmenu", function() 
        winState[0] = not winState[0]; if winState[0] then renderWindow[0] = true end
        sampSetCursorMode(winState[0] and 2 or 0)
    end)
    lua_thread.create(function()
        while true do
            wait(0)
            if isKeyDown(0x78) then stopBinds = true end -- F9
        end
    end)
    wait(-1)
end
