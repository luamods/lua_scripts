local imgui = require 'mimgui'
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8

-- Конфигурация
local info = {
    name = "LUA MODS | Professional Binder",
    version = "48.0",
    author = "LUA MODS",
    -- Замени на свою прямую ссылку на GitHub (RAW)
    updateUrl = "https://raw.githubusercontent.com/luamods/lua_scripts/refs/heads/main/binder/version.json", 
    tg = "https://t.me/zejksq_mods"
}

local winState = imgui.new.bool(false)
local isReady = false
local tab = 1
local binds = {}
local filePath = getWorkingDirectory() .. "\\config\\lua_mods_binder.ini"
local updateStatus = u8"Нажмите для проверки"

-- Цвета (float массивы для mimgui)
local bgColor = imgui.new.float[4](0.1, 0.1, 0.1, 0.9)
local btnColor = imgui.new.float[4](0.2, 0.2, 0.2, 1.0)

-- Буферы ввода
local addCmd = imgui.new.char[64]("")
local addTxt = imgui.new.char[2048]("") 

-- Безопасная конвертация цвета
local function HSVtoRGB(h, s, v)
    local r, g, b
    local i = math.floor(h * 6); local f = h * 6 - i
    local p = v * (1 - s); local q = v * (1 - f * s); local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return r, g, b
end

local rgbTick = 0

-- Работа с файлами
function saveAll()
    local f = io.open(filePath, "w")
    if f then
        f:write(string.format("BG_CLR|%.2f|%.2f|%.2f|%.2f\n", bgColor[0], bgColor[1], bgColor[2], bgColor[3]))
        f:write(string.format("BT_CLR|%.2f|%.2f|%.2f|%.2f\n", btnColor[0], btnColor[1], btnColor[2], btnColor[3]))
        for _, b in ipairs(binds) do
            local safeText = b.txt:gsub("\n", "\\n")
            f:write("BIND|" .. b.cmd .. "|" .. safeText .. "\n")
        end
        f:close()
    end
end

function loadAll()
    if doesFileExist(filePath) then
        local f = io.open(filePath, "r")
        if f then
            binds = {}
            for line in f:lines() do
                if line:find("^BG_CLR|") then
                    local r, g, b, a = line:match("^BG_CLR|([%d%.]+)|([%d%.]+)|([%d%.]+)|([%d%.]+)")
                    if r then bgColor[0], bgColor[1], bgColor[2], bgColor[3] = tonumber(r), tonumber(g), tonumber(b), tonumber(a) end
                elseif line:find("^BT_CLR|") then
                    local r, g, b, a = line:match("^BT_CLR|([%d%.]+)|([%d%.]+)|([%d%.]+)|([%d%.]+)")
                    if r then btnColor[0], btnColor[1], btnColor[2], btnColor[3] = tonumber(r), tonumber(g), tonumber(b), tonumber(a) end
                elseif line:find("^BIND|") then
                    local c, t = line:match("^BIND|(.-)|(.*)$")
                    if c and t then table.insert(binds, {cmd = c, txt = t:gsub("\\n", "\n")}) end
                end
            end
            f:close()
        end
    end
end

-- Проверка обновлений
function checkUpdates()
    updateStatus = u8"Проверка..."
    lua_thread.create(function()
        local tempFile = os.getenv("TEMP") .. "\\lua_mods_ver.txt"
        downloadUrlToFile(info.updateUrl, tempFile, function(id, status, p1, p2)
            if status == 6 then
                local f = io.open(tempFile, "r")
                if f then
                    local content = f:read("*a"):gsub("%s+", "")
                    f:close(); os.remove(tempFile)
                    if content == info.version then updateStatus = u8"У вас последняя версия"
                    else updateStatus = u8"Найдено обновление: v" .. u8(content) end
                end
            elseif status == -1 then updateStatus = u8"Ошибка соединения" end
        end)
    end)
end

-- Регистрация команд
function applyBinds()
    for _, b in ipairs(binds) do
        local command = b.cmd:gsub("^/", "")
        sampUnregisterChatCommand(command)
        sampRegisterChatCommand(command, function()
            lua_thread.create(function()
                for line in b.txt:gmatch("[^\r\n]+") do
                    if #line > 0 then
                        -- ФИКС КРАКОЗЯБР: Перевод из UTF8 в CP1251
                        sampSendChat(u8:decode(line))
                        wait(1150)
                    end
                end
            end)
        end)
    end
end

imgui.OnFrame(function() return isReady and winState[0] end, function()
    rgbTick = rgbTick + 0.002
    if rgbTick > 1 then rgbTick = 0 end
    local r, g, b = HSVtoRGB(rgbTick, 0.8, 1.0)
    
    local style = imgui.GetStyle()
    local function f(n) return tonumber(n) or 0.0 end
    
    -- Применение стилей (Фикс ImVec4)
    style.Colors[imgui.Col.Border] = imgui.ImVec4(f(r), f(g), f(b), 1.0)
    style.Colors[imgui.Col.WindowBg] = imgui.ImVec4(f(bgColor[0]), f(bgColor[1]), f(bgColor[2]), f(bgColor[3]))
    style.Colors[imgui.Col.Button] = imgui.ImVec4(f(btnColor[0]), f(btnColor[1]), f(btnColor[2]), f(btnColor[3]))
    style.Colors[imgui.Col.ButtonHovered] = imgui.ImVec4(f(btnColor[0])+0.1, f(btnColor[1])+0.1, f(btnColor[2])+0.1, f(btnColor[3]))
    style.Colors[imgui.Col.ButtonActive] = imgui.ImVec4(f(btnColor[0])-0.1, f(btnColor[1])-0.1, f(btnColor[2])-0.1, f(btnColor[3]))
    style.Colors[imgui.Col.Text] = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)

    imgui.SetNextWindowSize(imgui.ImVec2(600, 500), imgui.Cond.FirstUseEver)
    if imgui.Begin(u8(info.name), winState, imgui.WindowFlags.NoCollapse) then
        
        local btnW = (imgui.GetContentRegionAvail().x - 15) / 4
        if imgui.Button(u8"БИНДЫ", imgui.ImVec2(btnW, 35)) then tab = 1 end
        imgui.SameLine(); if imgui.Button(u8"НАСТРОЙКИ", imgui.ImVec2(btnW, 35)) then tab = 2 end
        imgui.SameLine(); if imgui.Button(u8"ОБНОВЛЕНИЯ", imgui.ImVec2(btnW, 35)) then tab = 3 end
        imgui.SameLine(); if imgui.Button(u8"ИНФО", imgui.ImVec2(btnW, 35)) then tab = 4 end
        imgui.Separator()

        if tab == 1 then
            imgui.InputText(u8"Команда", addCmd, 64)
            imgui.InputTextMultiline(u8"Текст", addTxt, 2048, imgui.ImVec2(-1, 80))
            if imgui.Button(u8"СОХРАНИТЬ", imgui.ImVec2(-1, 30)) then
                local c, t = ffi.string(addCmd), ffi.string(addTxt)
                if #c > 0 and #t > 0 then
                    table.insert(binds, {cmd = c, txt = t}); saveAll(); applyBinds()
                    ffi.fill(addCmd, 64); ffi.fill(addTxt, 2048)
                end
            end
            imgui.BeginChild("##bscroll", imgui.ImVec2(0, 0), true)
            for i, b in ipairs(binds) do
                imgui.TextColored(imgui.ImVec4(f(r), f(g), f(b), 1.0), "/" .. b.cmd)
                imgui.TextWrapped(u8(b.txt))
                imgui.SameLine(imgui.GetWindowWidth() - 40)
                if imgui.Button("X##"..i) then table.remove(binds, i) saveAll() end
                imgui.Separator()
            end
            imgui.EndChild()
        
        elseif tab == 2 then
            imgui.Text(u8"Цвет фона:")
            if imgui.ColorEdit4(u8"Фон Окна", bgColor) then saveAll() end
            imgui.Text(u8"Цвет кнопок:")
            if imgui.ColorEdit4(u8"Кнопки", btnColor) then saveAll() end

        elseif tab == 3 then
            imgui.Text(u8"Версия: " .. info.version)
            imgui.Text(u8"Статус: " .. updateStatus)
            if imgui.Button(u8"ПРОВЕРИТЬ", imgui.ImVec2(-1, 40)) then checkUpdates() end

        elseif tab == 4 then
            imgui.Text(u8"Автор: " .. info.author)
            imgui.Text(u8"Версия: " .. info.version)
            if imgui.Button("Telegram", imgui.ImVec2(-1, 30)) then os.execute("explorer " .. info.tg) end
        end
        imgui.End()
    end
end)

function main()
    while not isSampAvailable() do wait(100) end
    loadAll()
    applyBinds()
    sampRegisterChatCommand("bmenu", function() winState[0] = not winState[0] end)
    isReady = true
    while true do
        wait(0)
        -- Открытие на клавишу X (88)
        if isKeyJustPressed(88) and not sampIsChatInputActive() then winState[0] = not winState[0] end
    end
end