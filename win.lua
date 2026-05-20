-- win.lua
local composer = require("composer")
local widget = require("widget")
local audio = require("audio")

local scene = composer.newScene()

-- Глобальный канал для звука победы (чтобы не было наложения)
if not _G.winChannel then _G.winChannel = nil end

function scene:create(event)
    local group = self.view

    -- Фоновое изображение
    local bg = display.newImageRect("FOTO/Win.png", display.contentWidth, display.contentHeight)
    bg.x, bg.y = display.contentCenterX, display.contentCenterY
    group:insert(bg)

    -- Текст победы
    local text = display.newText("Победа! Уровень пройден.", display.contentCenterX, display.contentCenterY - 200, native.systemFont, 40)
    text:setFillColor(1, 1, 1)
    group:insert(text)

    -- Кнопка "В меню"
    local btn = widget.newButton{
        label = "В меню",
        x = display.contentCenterX, y = display.contentCenterY - 100,
        width = 200, height = 60,
        onPress = function()
            if _G.winChannel then
                audio.stop(_G.winChannel)
                _G.winChannel = nil
            end
            composer.gotoScene("author")
        end
    }
    group:insert(btn)
end

function scene:show(event)
    if event.phase == "did" then
        -- Останавливаем фоновую музыку (если играет)
        if _G.bgMusicChannel then
            audio.stop(_G.bgMusicChannel)
            _G.bgMusicChannel = nil
        end

        -- Останавливаем предыдущий звук победы (на всякий случай)
        if _G.winChannel then
            audio.stop(_G.winChannel)
            _G.winChannel = nil
        end

        -- Воспроизводим звук победы
        if _G.sounds.win then
            _G.winChannel = audio.play(_G.sounds.win, { channel = 1 })
            if _G.winChannel then
                --print("Звук победы запущен")
            else
                --print("Не удалось запустить звук победы")
            end
        else
            --print("Ошибка: _G.sounds.win = nil")
        end
    end
end

function scene:hide(event)
    if event.phase == "will" then
        if _G.winChannel then
            audio.stop(_G.winChannel)
            _G.winChannel = nil
        end
    end
end

function scene:destroy(event)
    if _G.winChannel then
        audio.stop(_G.winChannel)
        _G.winChannel = nil
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene