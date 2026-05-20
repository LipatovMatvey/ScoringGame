-- lose.lua
local composer = require("composer")
local widget = require("widget")
local audio = require("audio")

local scene = composer.newScene()

-- Глобальный канал для звука поражения
if not _G.loseChannel then _G.loseChannel = nil end

function scene:create(event)
    local group = self.view

    local bg = display.newImageRect("FOTO/GameOver.png", display.contentWidth, display.contentHeight)
    bg.x, bg.y = display.contentCenterX, display.contentCenterY
    group:insert(bg)

    local text = display.newText("Поражение! Игра окончена.", display.contentCenterX, display.contentCenterY - 200, native.systemFont, 40)
    text:setFillColor(1, 1, 1)
    group:insert(text)

    local btn = widget.newButton{
        label = "В меню",
        x = display.contentCenterX, y = display.contentCenterY - 100,
        width = 200, height = 60,
        onPress = function()
            if _G.loseChannel then
                audio.stop(_G.loseChannel)
                _G.loseChannel = nil
            end
            composer.gotoScene("author")
        end
    }
    group:insert(btn)
end

function scene:show(event)
    if event.phase == "did" then
        -- Останавливаем фоновую музыку
        if _G.bgMusicChannel then
            audio.stop(_G.bgMusicChannel)
            _G.bgMusicChannel = nil
        end

        -- Останавливаем предыдущий звук поражения (на всякий случай)
        if _G.loseChannel then
            audio.stop(_G.loseChannel)
            _G.loseChannel = nil
        end

        -- Воспроизводим звук поражения
        if _G.sounds.lose then
            _G.loseChannel = audio.play(_G.sounds.lose)
            if _G.loseChannel then
                --print("Звук поражения запущен")
            else
                --print("Не удалось запустить звук поражения")
            end
        else
            --print("Ошибка: _G.sounds.lose = nil")
        end
    end
end

function scene:hide(event)
    if event.phase == "will" then
        if _G.loseChannel then
            audio.stop(_G.loseChannel)
            _G.loseChannel = nil
        end
    end
end

function scene:destroy(event)
    if _G.loseChannel then
        audio.stop(_G.loseChannel)
        _G.loseChannel = nil
    end
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene