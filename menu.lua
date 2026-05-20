-- menu.lua (с анимацией машины)
local composer = require("composer")
local widget = require("widget")
local scene = composer.newScene()

function scene:create(event)
    local group = self.view

    -- Фон
    local bg = display.newRect(display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)
    bg:setFillColor(0.2, 0.2, 0.4)
    group:insert(bg)

    -- Заголовок выбора уровня
    local title = display.newText("Выберите уровень", display.contentCenterX + 300, 100, native.systemFont, 36)
    title:setFillColor(1, 1, 1)
    group:insert(title)

    -- Заголовок правил
    local rulesTitle = display.newText("Правила игры", display.contentCenterX - 300, 100, native.systemFont, 36)
    rulesTitle:setFillColor(1, 1, 1)
    group:insert(rulesTitle)

    -- Текст правил
    local ruleText1 = display.newText(
        "Уровень 1: Выживите 10 секунд,\nизбегая дружелюбных существ.\nПоражение: потеря всех жизней (3).",
        display.contentCenterX - 450,
        180,
        native.systemFont,
        20
    )
    ruleText1:setFillColor(1, 1, 1)
    ruleText1.anchorX = 0
    group:insert(ruleText1)

    local ruleText2 = display.newText(
        "Уровень 2: Выживите 10 секунд, уничтожьте\n5 бандитов (попаданием или касанием).\nПоражение: потеря жизней.",
        display.contentCenterX - 450,
        280,
        native.systemFont,
        20
    )
    ruleText2:setFillColor(1, 1, 1)
    ruleText2.anchorX = 0
    group:insert(ruleText2)

    local ruleText3 = display.newText(
        "Уровень 3: Выживите 10 секунд, уничтожьте\n5 бандитов, они стреляют.\nПоражение: потеря жизней .\n\nУправление: касание экрана — прыжок.\nНа 3 уровне появляется кнопка «Огонь».",
        display.contentCenterX - 450,
        405,
        native.systemFont,
        20
    )
    ruleText3:setFillColor(1, 1, 1)
    ruleText3.anchorX = 0
    group:insert(ruleText3)
    local carSheet = graphics.newImageSheet("FOTO/CarInMenu.png", {
        frames = {
            { x = 0,    y = 0, width = 211, height = 146 },
            { x = 273,  y = 0, width = 313, height = 146 },
            { x = 628,  y = 0, width = 423, height = 146 },
            { x = 1094,  y = 0, width = 329, height = 146 },
            { x = 1485,  y = 0, width = 211, height = 146 },
            { x = 1771, y = 0, width = 301, height = 146 }
        }
    })

    local carSprite = display.newSprite(carSheet, {
        name = "drive",
        start = 1,
        count = 6,
        time = 1500,        -- скорость анимации (мс на цикл)
        loopCount = 0      -- бесконечное повторение
    })
    carSprite:play()
    -- Размещаем под текстом правил, в левой части экрана
    carSprite.x = display.contentCenterX
    carSprite.y = 650
    carSprite:scale(0.75, 0.75)  -- уменьшаем, чтобы вписать в интерфейс
    group:insert(carSprite)

    -- Вспомогательная функция для создания стилизованной кнопки
    local function createStyledButton(label, x, y, width, height, onPressCallback)
        local button = widget.newButton{
            label = label,
            x = x,
            y = y,
            width = width,
            height = height,
            fontSize = 24,
            labelColor = { default = { 1, 1, 1 }, over = { 0.8, 0.8, 0.8 } },
            fillColor = { default = { 0.3, 0.6, 0.9, 1 }, over = { 0.2, 0.5, 0.8, 1 } },
            strokeColor = { default = { 1, 1, 1, 0.8 }, over = { 1, 1, 1, 1 } },
            strokeWidth = 2,
            shape = "roundedRect",
            cornerRadius = 12,
            onPress = onPressCallback,
            onRelease = function() end
        }
        return button
    end

    -- Кнопки уровней
    local levelButtons = {}
    for i = 1, 3 do
        local btn = createStyledButton(
            "Уровень " .. i,
            display.contentCenterX + 300,
            200 + (i - 1) * 90,
            200,
            60,
            function()
                composer.gotoScene("game", { params = { level = i } })
            end
        )
        group:insert(btn)
        levelButtons[i] = btn
    end

    -- Кнопка "Назад"
    local backBtn = widget.newButton{
        label = "Назад",
        x = display.contentCenterX + 300,
        y = 470,
        width = 150,
        height = 50,
        fontSize = 24,
        labelColor = { default = { 1, 1, 1 }, over = { 0.9, 0.9, 0.9 } },
        fillColor = { default = { 0.6, 0.3, 0.3, 1 }, over = { 0.5, 0.2, 0.2, 1 } },
        strokeColor = { default = { 1, 1, 1, 0.8 }, over = { 1, 1, 1, 1 } },
        strokeWidth = 2,
        shape = "roundedRect",
        cornerRadius = 12,
        onPress = function()
            composer.gotoScene("author")
        end
    }
    group:insert(backBtn)
end

function scene:show(event) end
function scene:hide(event) end
function scene:destroy(event) end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene