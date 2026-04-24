-- Игра 
-- Автор: Липатов Матвей


-- Подключение модулей
local physics = require("physics")
physics.start()
physics.setGravity(0, 20)   -- гравитация вниз

local widget = require("widget")
local audio = require("audio")

-- Отключаем стандартный вывод
display.setStatusBar(display.HiddenStatusBar)

-- Глобальные переменные состояния
local gameState = "menu"
local currentLevel = 1
local gameGroup = nil
local gameObjects = {}
local gameTimers = {}
local lives = 3
local score = 0
local timeLeft = 0
local levelDuration = {10, 10, 10}   -- для 2 и 3 уровня тоже 10 секунд (условие времени)
local requiredScore = {0, 5, 5}
local isGameActive = true
local player = nil
local ground = nil
local canJump = true
local gameOverlay = nil

-- Бесконечный фон
local background = nil
local background2 = nil
local bgTimer = nil
local scrollSpeed = 150   -- скорость прокрутки (пикселей/сек)

-- Флаг, чтобы победа не срабатывала дважды
local winTriggered = false

-- --- ЗВУКИ ---
local bgMusicChannel = nil
local currentMusicFile = nil
local jumpSound, shootSound, hitSound, pointSound, winSound, loseSound

-- Список фоновых песен
local musicFiles = {
    "MUSIC/FonMusic.mp3",
    "MUSIC/FonMusic2.mp3",
    "MUSIC/FonMusic3.mp3"
}

local function loadSound(filename)
    local filePath = system.pathForFile(filename)
    if filePath then return audio.loadSound(filename) end
    return nil
end

jumpSound = loadSound("MUSIC/jump.wav")   -- звук прыжка машины
shootSound = loadSound("MUSIC/shoot.wav") -- звук выстрела
hitSound = loadSound("MUSIC/hit.wav")     -- звук получения урона
pointSound = loadSound("MUSIC/point.wav") -- звук набора очка
winSound = loadSound("MUSIC/win.wav")     -- звук победы
loseSound = loadSound("MUSIC/lose.wav")   -- звук поражения

local function playSound(snd) if snd then audio.play(snd) end end

local function stopMusic()
    if bgMusicChannel then
        audio.stop(bgMusicChannel)
        bgMusicChannel = nil
    end
end

-- Проигрывание случайной фоновой музыки (с возможным исключением текущей)
local function playRandomMusic(avoidCurrent)
    stopMusic()
    local randomIndex
    if avoidCurrent and currentMusicFile then
        local currentIndex
        for i, file in ipairs(musicFiles) do
            if file == currentMusicFile then
                currentIndex = i
                break
            end
        end
        if currentIndex and #musicFiles > 1 then
            repeat
                randomIndex = math.random(1, #musicFiles)
            until randomIndex ~= currentIndex
        else
            randomIndex = math.random(1, #musicFiles)
        end
    else
        randomIndex = math.random(1, #musicFiles)
    end
    local newMusicFile = musicFiles[randomIndex]
    currentMusicFile = newMusicFile
    local bgMusic = audio.loadStream(newMusicFile)
    if bgMusic then
        bgMusicChannel = audio.play(bgMusic, { loops = -1 })
    end
end

-- ========== АНИМАЦИИ ==========

-- 1. Взрыв при уничтожении бандита
local function createExplosion(x, y)
    local explosion = display.newCircle(x, y, 8)
    explosion:setFillColor(1, 0.5, 0)
    explosion.alpha = 1
    transition.to(explosion, { time = 200, xScale = 2, yScale = 2, alpha = 0, onComplete = function() explosion:removeSelf() end })
end

-- 2. Мигание машины при получении урона (безопасная версия)
local function flashPlayer()
    -- if not player then return end
    -- local body = player[1] -- первый дочерний элемент — кузов
    -- if not body or not body.setFillColor then return end
    -- local originalColor = { 0, 0.5, 1 }
    -- local count = 0
    -- local flashTimer
    -- local function flashStep()
    --     -- Проверяем, что объекты всё ещё существуют и игра активна
    --     if not player or not body or not body.setFillColor or not isGameActive then
    --         if flashTimer then timer.cancel(flashTimer) end
    --         return
    --     end
    --     count = count + 1
    --     if count % 2 == 1 then
    --         body:setFillColor(1, 0, 0)  -- красный
    --     else
    --         body:setFillColor(unpack(originalColor))
    --     end
    --     if count < 6 then
    --         flashTimer = timer.performWithDelay(100, flashStep)
    --     else
    --         body:setFillColor(unpack(originalColor))
    --     end
    -- end
    -- flashStep()
    if not player then return end
    local originalAlpha = player.alpha
    transition.to(player, { time = 100, alpha = 0.5 })
    transition.to(player, { time = 100, alpha = originalAlpha, delay = 100 })
    transition.to(player, { time = 100, alpha = 0.5, delay = 200 })
    transition.to(player, { time = 100, alpha = originalAlpha, delay = 300 })
end

-- 3. Парящий текст "+1"
local function showScorePopup(x, y)
    local textObj = display.newText("+1", x, y, native.systemFont, 24)
    textObj:setFillColor(1, 1, 0)
    transition.to(textObj, { time = 800, y = y - 50, alpha = 0, onComplete = function() textObj:removeSelf() end })
end

-- 4. Тряска экрана
local function shakeScreen()
    if not gameGroup then return end
    local originalX = gameGroup.x
    local originalY = gameGroup.y
    transition.to(gameGroup, { time = 50, x = originalX + 10, y = originalY + 5 })
    transition.to(gameGroup, { time = 50, x = originalX - 10, y = originalY - 5, delay = 50 })
    transition.to(gameGroup, { time = 50, x = originalX, y = originalY, delay = 100 })
end

-- 5. Анимация прыжка (сжатие/растяжение)
local function animateJump()
    if not player then return end
    transition.to(player, { time = 100, xScale = 1.2, yScale = 0.8 })
    timer.performWithDelay(100, function()
        if player then
            transition.to(player, { time = 100, xScale = 1, yScale = 1 })
        end
    end)
end

-- ========== БЕСКОНЕЧНЫЙ ФОН ==========
local function createScrollingBackground()
    if background then return end  -- если фон уже есть, не создаём повторно
    -- Удаляем старый фон, если есть (на всякий случай)
    if background then background:removeSelf() end
    if background2 then background2:removeSelf() end
    if bgTimer then timer.cancel(bgTimer) end

    local screenW = display.contentWidth
    local screenH = display.contentHeight

    -- Создаём две копии фона, растянутые на весь экран
    background = display.newImageRect("FOTO/FonLvl.png", screenW, screenH)
    background.anchorX = 0
    background.x = 0
    -- Выравниваем фон по нижнему краю экрана (чтобы дорога совпадала с землёй)
    background.y = display.contentHeight - background.height + 375
    background:toBack()

    background2 = display.newImageRect("FOTO/FonLvl.png", screenW, screenH)
    background2.anchorX = 0
    background2.x = screenW   -- ставим вторую копию справа от первой
    background2.y = display.contentHeight - background2.height + 375
    background2:toBack()

    if gameGroup then
        gameGroup:insert(background)
        gameGroup:insert(background2)
    end

    -- Таймер анимации прокрутки
    bgTimer = timer.performWithDelay(16, function()
        if not isGameActive or not background or not background2 then return end
        background.x = background.x - scrollSpeed * 0.016
        background2.x = background2.x - scrollSpeed * 0.016

        -- Бесконечная прокрутка: если картинка ушла влево, переносим её вправо
        if background.x + background.width < 0 then
            background.x = background2.x + background2.width
        end
        if background2.x + background2.width < 0 then
            background2.x = background.x + background.width
        end
    end, 0)
    table.insert(gameTimers, bgTimer)
end

-- ========== ОБЩАЯ ЗЕМЛЯ И ИГРОК ==========
local function createGroundAndPlayer()
    ground = display.newRect(display.contentCenterX, display.contentHeight-50, display.contentWidth, 20)
    ground:setFillColor(0.4,0.4,0.4)
    ground.anchorY = 0
    ground.y = display.contentHeight-50
    physics.addBody(ground, "static", { friction=1 })
    ground.ID = "ground"
    
    player = display.newImageRect("FOTO/car1.png", 140, 75)
    player.x, player.y = 100, ground.y - 15
    player.ID = "player"
    physics.addBody(player, "dynamic", { density=1, friction=0.5, bounce=0.2 })
    player.isFixedRotation = true
    
    gameGroup:insert(ground)
    gameGroup:insert(player)
end

-- ========== ОСНОВНЫЕ ФУНКЦИИ ==========

local function clearGame()
    if gameGroup then gameGroup:removeSelf(); gameGroup = nil end
    for _, tid in ipairs(gameTimers) do 
        if tid then timer.cancel(tid) end
    end
    gameTimers = {}
    gameObjects = {}
    isGameActive = false
    winTriggered = false
    if player and player.removeSelf then player:removeSelf() end
    player = nil
    ground = nil
    if background then background:removeSelf(); background = nil end
    if background2 then background2:removeSelf(); background2 = nil end
    if bgTimer then timer.cancel(bgTimer); bgTimer = nil end
end

local function showMessage(text, isWin, onComplete)
    local msgGroup = display.newGroup()
    local rect = display.newRect(0, 0, display.contentWidth, display.contentHeight)
    rect:setFillColor(0,0,0,0.7)
    msgGroup:insert(rect)
    local msgText = display.newText(text, display.contentCenterX, display.contentCenterY-50, native.systemFont, 40)
    msgText:setFillColor(1,1,1)
    msgGroup:insert(msgText)
    local btn = widget.newButton{
        label = "В меню",
        x = display.contentCenterX, y = display.contentCenterY + 50,
        width = 200, height = 60,
        onPress = function()
            msgGroup:removeSelf()
            if onComplete then onComplete() end
        end
    }
    msgGroup:insert(btn)
end

-- Функция для завершения игры с победой или поражением
local function endGame(isVictory)
    if winTriggered then return end
    winTriggered = true
    isGameActive = false
    stopMusic()          -- останавливаем фоновую музыку
    clearGame()          -- удаляем все игровые объекты, таймеры, группу
    if isVictory then
        playSound(winSound)
        showMessage("Победа! Уровень пройден.", true, returnToMenu)
    else
        playSound(loseSound)
        showMessage("Поражение! Игра окончена.", false, returnToMenu)
    end
end

-- Функция проверки победы (вызывается при наборе очков или окончании времени)
local function tryWin()
    if not isGameActive or winTriggered then return false end
    if currentLevel == 1 then
        if timeLeft <= 0 and lives > 0 then
            endGame(true)
            return true
        end
    else
        if timeLeft <= 0 and score >= requiredScore[currentLevel] and lives > 0 then
            endGame(true)
            return true
        end
    end
    return false
end

-- ========== ЛОГИКА УРОВНЕЙ ==========

-- Уровень 1: только дружественные объекты (зелёные)
local function startLevel1Spawning()
    local function spawnFriendly()
        if not isGameActive or not ground then return end
        local friendly = display.newRect(display.contentWidth, ground.y - 20, 40, 40)
        friendly:setFillColor(0,1,0)
        friendly.ID = "friendly"
        physics.addBody(friendly, "kinematic", { isSensor=true })
        friendly:setLinearVelocity(-200, 0)
        gameGroup:insert(friendly)
        table.insert(gameObjects, friendly)
        
        local function removeOffscreen()
            if friendly and friendly.x and friendly.x < -50 then
                friendly:removeSelf()
                for i,obj in ipairs(gameObjects) do
                    if obj == friendly then table.remove(gameObjects,i); break end
                end
                Runtime:removeEventListener("enterFrame", removeOffscreen)
            end
        end
        Runtime:addEventListener("enterFrame", removeOffscreen)
    end
    
    local spawnTimer = timer.performWithDelay(2500, spawnFriendly, 0)
    table.insert(gameTimers, spawnTimer)
end

-- Уровень 2: смесь друзей и врагов (красные и зелёные)
local function startLevel2Spawning()
    local function spawnMixed()
        if not isGameActive or not ground then return end
        local isBandit = (math.random() > 0.5)
        local obj = display.newRect(display.contentWidth, ground.y-20, 40, 40)
        if isBandit then
            obj:setFillColor(1,0,0)
            obj.ID = "bandit"
        else
            obj:setFillColor(0,1,0)
            obj.ID = "friendly"
        end
        physics.addBody(obj, "kinematic", { isSensor=true })
        obj:setLinearVelocity(-200, 0)
        gameGroup:insert(obj)
        table.insert(gameObjects, obj)
    end
    
    local spawnTimer = timer.performWithDelay(2000, spawnMixed, 0)
    table.insert(gameTimers, spawnTimer)
end

-- Уровень 3: смесь + стрельба
local bullets = {}
local enemyBullets = {}
local shootButton = nil

local function startLevel3Features()
    -- Добавляем кнопку стрельбы
    local bulletY = ground.y - 20
    shootButton = widget.newButton{
        label = "Огонь",
        x = display.contentWidth - 80,
        y = display.contentHeight - 80,
        width = 100, height = 60,
        onPress = function()
            if not isGameActive or not player then return end
            playSound(shootSound)
            local bullet = display.newImageRect("FOTO/bullet.png", 50, 24)
            bullet.x, bullet.y = player.x + 30, ground.y - 20
            bullet.ID = "playerBullet"
            physics.addBody(bullet, "dynamic", { isSensor=true })
            bullet.gravityScale = 0
            bullet.isFixedRotation = true
            bullet.linearDamping = 0
            bullet.isBullet = true
            bullet:setLinearVelocity(400, 0)
            gameGroup:insert(bullet)
            table.insert(bullets, bullet)
        end
    }
    gameGroup:insert(shootButton)
    
    -- Враги стреляют
    local function enemyShoot(bandit)
        if not isGameActive or not bandit or not bandit.x or bandit.x < 0 then
            return
        end
        local ebullet = display.newImageRect("FOTO/bullet2.png", 50, 24)
        ebullet.x, ebullet.y = bandit.x - 20, ground.y - 20
        ebullet.ID = "enemyBullet"
        physics.addBody(ebullet, "dynamic", { isSensor=true })
        ebullet.gravityScale = 0
        ebullet.isFixedRotation = true
        ebullet.linearDamping = 0
        ebullet.isBullet = true
        ebullet:setLinearVelocity(-300, 0)
        gameGroup:insert(ebullet)
        table.insert(enemyBullets, ebullet)
    end
    
    local function addShootToBandit()
        for _, obj in ipairs(gameObjects) do
            if obj.ID == "bandit" and not obj.hasShoot then
                obj.hasShoot = true
                local st = timer.performWithDelay(1500, function() enemyShoot(obj) end, 0)
                obj.shootTimer = st
                table.insert(gameTimers, st)
            end
        end
    end
    local checkTimer = timer.performWithDelay(500, addShootToBandit, 0)
    table.insert(gameTimers, checkTimer)
end

-- Инициализация уровня (общая для всех)
local function initLevel(level)
    createScrollingBackground()
    createGroundAndPlayer()
    
    if level == 1 then
        startLevel1Spawning()
    elseif level == 2 then
        startLevel2Spawning()
    elseif level == 3 then
        startLevel2Spawning()   -- сначала спавн смеси
        startLevel3Features()   -- потом добавляем стрельбу
    end
end

-- --- ОБРАБОТКА СТОЛКНОВЕНИЙ (С АНИМАЦИЯМИ) ---
local function onCollision(event)
    if not isGameActive then return end
    local obj1, obj2 = event.object1, event.object2
    if event.phase ~= "began" then return end
    
    if (obj1.ID == "player" and obj2.ID) or (obj2.ID == "player" and obj1.ID) then
        local other = (obj1.ID == "player") and obj2 or obj1
        if other.ID == "friendly" then
            lives = lives - 1
            playSound(hitSound)
            other:removeSelf()
            if gameOverlay and gameOverlay.livesText then gameOverlay.livesText.text = "Жизни: " .. lives end
            flashPlayer()        -- мигание машины
            shakeScreen()        -- тряска экрана
            if lives <= 0 then
                endGame(false)
            end
        elseif other.ID == "bandit" and (currentLevel == 2 or currentLevel == 3) then
            score = score + 1
            playSound(pointSound)
            createExplosion(other.x, other.y)
            showScorePopup(other.x, other.y)
            if other.shootTimer then 
                timer.cancel(other.shootTimer)
                other.shootTimer = nil
            end
            other:removeSelf()
            if gameOverlay and gameOverlay.scoreText then gameOverlay.scoreText.text = "Очки: " .. score end
            tryWin()
        end
    end
    
    if obj1.ID == "playerBullet" or obj2.ID == "playerBullet" then
        local bullet = (obj1.ID == "playerBullet") and obj1 or obj2
        local target = (obj1.ID == "playerBullet") and obj2 or obj1
        if target.ID == "bandit" then
            score = score + 1
            playSound(pointSound)
            createExplosion(target.x, target.y)
            showScorePopup(target.x, target.y)
            if target.shootTimer then 
                timer.cancel(target.shootTimer)
                target.shootTimer = nil
            end
            target:removeSelf()
            bullet:removeSelf()
            if gameOverlay and gameOverlay.scoreText then gameOverlay.scoreText.text = "Очки: " .. score end
            tryWin()
        elseif target.ID == "friendly" then
            lives = lives - 1
            playSound(hitSound)
            target:removeSelf()
            bullet:removeSelf()
            if gameOverlay and gameOverlay.livesText then gameOverlay.livesText.text = "Жизни: " .. lives end
            flashPlayer()
            shakeScreen()
            if lives <= 0 then
                endGame(false)
            end
        elseif target.ID == "enemyBullet" then
            bullet:removeSelf()
            target:removeSelf()
        end
    end
    
    if (obj1.ID == "enemyBullet" and obj2.ID == "player") or (obj2.ID == "enemyBullet" and obj1.ID == "player") then
        lives = lives - 1
        playSound(hitSound)
        if obj1.ID == "enemyBullet" then obj1:removeSelf() else obj2:removeSelf() end
        if gameOverlay and gameOverlay.livesText then gameOverlay.livesText.text = "Жизни: " .. lives end
        flashPlayer()
        shakeScreen()
        if lives <= 0 then
            endGame(false)
        end
    end
end

-- --- ПРЫЖОК (С АНИМАЦИЕЙ) ---
local function jump(event)
    if event.phase == "began" and isGameActive and canJump and player then
        local vx, vy = player:getLinearVelocity()
        if vy and vy == 0 then
            player:setLinearVelocity(vx or 0, -500)
            playSound(jumpSound)
            animateJump()
            canJump = false
            timer.performWithDelay(500, function() canJump = true end)
        end
    end
end

-- --- ЗАПУСК ИГРЫ ---
local function startGame(level)
    clearGame()
    currentLevel = level
    gameState = "game"
    lives = 3
    score = 0
    timeLeft = levelDuration[level]
    isGameActive = true
    canJump = true
    winTriggered = false
    
    gameGroup = display.newGroup()
    
    gameOverlay = display.newGroup()
    local bgBar = display.newRect(0, 0, 2500, 60)
    bgBar:setFillColor(0,0,0,0.6)
    gameOverlay:insert(bgBar)
    local livesText = display.newText("Жизни: " .. lives, 80, 20, native.systemFont, 25)
    livesText:setFillColor(1,1,1)
    gameOverlay:insert(livesText)
    local scoreText = display.newText("Очки: " .. score, 220, 20, native.systemFont, 25)
    scoreText:setFillColor(1,1,1)
    gameOverlay:insert(scoreText)
    local timerText = display.newText("Время: " .. timeLeft, display.contentWidth-120, 20, native.systemFont, 25)
    timerText:setFillColor(1,1,1)
    gameOverlay:insert(timerText)
    gameOverlay.livesText = livesText
    gameOverlay.scoreText = scoreText
    gameOverlay.timerText = timerText
    gameGroup:insert(gameOverlay)
    
    -- Инициализируем уровень (фон, земля, игрок, спавн)
    initLevel(level)
    
    -- Убедимся, что фон позади всего (Z-порядок)
    if background then background:toBack() end
    if background2 then background2:toBack() end
    
    -- Таймер для всех уровней
    local timeExpired = false
    local countdownTimer = timer.performWithDelay(1000, function()
        if not isGameActive or winTriggered then return end
        
        if not timeExpired then
            if timeLeft > 0 then
                timeLeft = timeLeft - 1
            end
            if timeLeft <= 0 then
                timeExpired = true
                if currentLevel == 1 then
                    if lives > 0 then
                        endGame(true)
                    else
                        endGame(false)
                    end
                else
                    if gameOverlay and gameOverlay.timerText then
                        gameOverlay.timerText.text = "Время вышло!"
                    end
                    tryWin()
                end
            else
                if gameOverlay and gameOverlay.timerText then
                    gameOverlay.timerText.text = "Время: " .. timeLeft
                end
            end
        else
            if currentLevel ~= 1 then
                tryWin()
            end
        end
    end, 0)
    table.insert(gameTimers, countdownTimer)
    
    Runtime:addEventListener("touch", jump)
    Runtime:addEventListener("collision", onCollision)
    
    local function updateObjects()
        if not isGameActive then return end
        for i=#gameObjects,1,-1 do
            local obj = gameObjects[i]
            if obj and obj.x and (obj.x < -100 or obj.x > display.contentWidth+100) then
                if obj.shootTimer then 
                    timer.cancel(obj.shootTimer)
                    obj.shootTimer = nil
                end
                obj:removeSelf()
                table.remove(gameObjects, i)
            end
        end
        for i=#bullets,1,-1 do
            local b = bullets[i]
            if b and b.x and (b.x > display.contentWidth+50 or b.x < -50) then
                b:removeSelf()
                table.remove(bullets, i)
            end
        end
        for i=#enemyBullets,1,-1 do
            local eb = enemyBullets[i]
            if eb and eb.x and (eb.x > display.contentWidth+50 or eb.x < -50) then
                eb:removeSelf()
                table.remove(enemyBullets, i)
            end
        end
    end
    local frameTimer = timer.performWithDelay(50, updateObjects, 0)
    table.insert(gameTimers, frameTimer)
end

-- --- ВОЗВРАТ В МЕНЮ ---
function returnToMenu()
    clearGame()
    Runtime:removeEventListener("touch", jump)
    Runtime:removeEventListener("collision", onCollision)
    gameState = "menu"
    audio.stop()
    playRandomMusic(true)
    createMainMenu()
end

-- --- ГЛАВНОЕ МЕНЮ ---
function createMainMenu()
    local menuGroup = display.newGroup()
    local bg = display.newRect(display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)
    bg:setFillColor(0.2,0.2,0.4)
    menuGroup:insert(bg)
    local title = display.newText("DRIVING ADVENTURE", display.contentCenterX, 100, native.systemFont, 40)
    title:setFillColor(1,1,0)
    menuGroup:insert(title)
    local author = display.newText("Автор: Липатов Матвей 24ВП2", display.contentCenterX, 160, native.systemFont, 20)
    author:setFillColor(1,1,1)
    menuGroup:insert(author)
    
    local startBtn = widget.newButton{
        label = "Начать игру",
        x = display.contentCenterX, y = display.contentCenterY,
        width = 200, height = 60,
        onPress = function()
            menuGroup:removeSelf()
            createLevelSelect()
        end
    }
    menuGroup:insert(startBtn)
    
    local musicBtn = widget.newButton{
        label = "Сменить музыку",
        x = display.contentCenterX, y = display.contentCenterY + 80,
        width = 200, height = 50,
        onPress = function()
            playRandomMusic(true)
        end
    }
    menuGroup:insert(musicBtn)
end

-- --- МЕНЮ ВЫБОРА УРОВНЯ ---
function createLevelSelect()
    local selectGroup = display.newGroup()
    local bg = display.newRect(display.contentCenterX, display.contentCenterY, display.contentWidth, display.contentHeight)
    bg:setFillColor(0.3,0.3,0.5)
    selectGroup:insert(bg)
    local title = display.newText("Выберите уровень", display.contentCenterX, 100, native.systemFont, 35)
    title:setFillColor(1,1,1)
    selectGroup:insert(title)
    for i=1,3 do
        local btn = widget.newButton{
            label = "Уровень " .. i,
            x = display.contentCenterX, y = 200 + (i-1)*100,
            width = 200, height = 60,
            onPress = function()
                selectGroup:removeSelf()
                startGame(i)
            end
        }
        selectGroup:insert(btn)
    end
    local backBtn = widget.newButton{
        label = "Назад",
        x = display.contentCenterX, y = display.contentHeight - 80,
        width = 150, height = 50,
        onPress = function()
            selectGroup:removeSelf()
            createMainMenu()
        end
    }
    selectGroup:insert(backBtn)
end

-- --- ЗАПУСК ---
playRandomMusic()
createMainMenu()