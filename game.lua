-- game.lua (4 копии фона, запас влево 2 экрана)
local composer = require("composer")
local widget = require("widget")
local physics = require("physics")
local audio = require("audio")

local scene = composer.newScene()

-- Параметры уровня
local level = 1
local lives, score, timeLeft
local isGameActive = true
local winTriggered = false
local canJump = true

local gameGroup = nil
local gameObjects = {}
local gameTimers = {}
local bullets = {}
local enemyBullets = {}
local player = nil
local ground = nil
local shootButton = nil
local gameOverlay = nil

-- Четыре копии фона
local backgrounds = {}
local scrollSpeed = 150
local bgTimer = nil
local accumulatedOffset = 0

local levelDuration = {10, 10, 10}
local requiredScore = {0, 5, 5}
local timeExpired = false

-- Функция создания мирного спрайта (анимация)
local function createFriendlySprite(x, groundY)
    groundY = groundY or (display.contentHeight - 50)
    
    local sheet = graphics.newImageSheet("FOTO/Friendly2.png", {
        frames = {
            { x=0,   y=0, width=244, height=459 },
            { x=375, y=0, width=244, height=459 },
            { x=724, y=0, width=244, height=459 },
            { x=1120, y=0, width=244, height=459 }
        }
    })
    
    local sprite = display.newSprite(sheet, { 
        name="walk", 
        start=1, 
        count=4, 
        time=1200,
        loopCount=0 
    })
    sprite:scale(0.2, 0.2)
    sprite.anchorX, sprite.anchorY = 0.5, 0.5
    sprite:play()
    local group = display.newGroup()
    group:insert(sprite)
    group.x = x
    local spriteHeight = 459 * 0.25
    group.y = groundY - spriteHeight/2 + 15
    group.groundY = groundY
    group.ID = "friendly"
    physics.addBody(group, "kinematic", { 
        isSensor = true,
        shape = { -60, -50, 60, -50, 60, 50, -60, 50 }
    })
    group:setLinearVelocity(-200, 0)
    return group
end

-- Функция создания бандита
local function createBanditSprite(x, groundY)
    groundY = groundY or (display.contentHeight - 50)
    
    local sheet = graphics.newImageSheet("FOTO/Bandit.png", {
        frames = {
            { x=0, y=0, width=226, height=432 },
            { x=328, y=0, width=226, height=432 },
            { x=653, y=0, width=226, height=432 },
            { x=995, y=0, width=226, height=432 }
        }
    })
    local sprite = display.newSprite(sheet, { 
        name="walk", 
        start=1, 
        count=4, 
        time=1200,
        loopCount=0 
    })
    sprite:scale(0.25, 0.25)
    sprite.anchorX, sprite.anchorY = 0.5, 0.5
    sprite:play()
    local group = display.newGroup()
    group:insert(sprite)
    group.x = x
    local spriteHeight = 432 * 0.25
    group.y = groundY - spriteHeight / 2
    group.groundY = groundY
    group.ID = "bandit"
    physics.addBody(group, "kinematic", { 
        isSensor = true,
        shape = { -60, -50, 60, -50, 60, 50, -60, 50 }
    })
    group:setLinearVelocity(-200, 0)
    group.hasShoot = false
    group.shootTimer = nil
    return group
end

-- Проверка победы
local function tryWin()
    if not isGameActive or winTriggered then return false end
    if level == 1 then
        if timeExpired and lives > 0 then
            winTriggered = true
            _G.stopMusic()
            composer.gotoScene("win")
            return true
        end
    else
        if timeExpired and score >= requiredScore[level] and lives > 0 then
            winTriggered = true
            _G.stopMusic()
            composer.gotoScene("win")
            return true
        end
    end
    return false
end

-- Проверка поражения
local function checkLose()
    if lives <= 0 and not winTriggered then
        composer.gotoScene("lose")
        return true
    end
    return false
end

-- Вспомогательные функции
local function createExplosion(x, y)
    local explosion = display.newCircle(x, y, 8)
    explosion:setFillColor(1, 0.5, 0)
    explosion.alpha = 1
    transition.to(explosion, {
        time = 200,
        xScale = 2,
        yScale = 2,
        alpha = 0,
        onComplete = function()
            if explosion and explosion.removeSelf then explosion:removeSelf() end
        end
    })
    if gameGroup then gameGroup:insert(explosion) end
end

local function flashPlayer()
    if not player then return end
    local originalAlpha = player.alpha
    transition.to(player, { time = 100, alpha = 0.5 })
    transition.to(player, { time = 100, alpha = originalAlpha, delay = 100 })
    transition.to(player, { time = 100, alpha = 0.5, delay = 200 })
    transition.to(player, { time = 100, alpha = originalAlpha, delay = 300 })
end

local function showScorePopup(x, y)
    local textObj = display.newText("+1", x, y, native.systemFont, 24)
    textObj:setFillColor(1, 1, 0)
    transition.to(textObj, {
        time = 800,
        y = y - 50,
        alpha = 0,
        onComplete = function()
            if textObj and textObj.removeSelf then textObj:removeSelf() end
        end
    })
    if gameGroup then gameGroup:insert(textObj) end
end

local function shakeScreen()
    if not gameGroup then return end
    local originalX = gameGroup.x
    local originalY = gameGroup.y
    transition.to(gameGroup, { time = 50, x = originalX + 10, y = originalY + 5 })
    transition.to(gameGroup, { time = 50, x = originalX - 10, y = originalY - 5, delay = 50 })
    transition.to(gameGroup, { time = 50, x = originalX, y = originalY, delay = 100 })
end

local function animateJump()
    if not player then return end
    transition.to(player, { time = 100, xScale = 1.2, yScale = 0.8 })
    timer.performWithDelay(100, function()
        if player then
            transition.to(player, { time = 100, xScale = 1, yScale = 1 })
        end
    end)
end

-- ==== БЕСКОНЕЧНЫЙ ФОН ====
local function createScrollingBackground()
    if backgrounds[1] then return end
    if bgTimer then timer.cancel(bgTimer); bgTimer = nil end

    local screenW = display.contentWidth
    local screenH = display.contentHeight

    for i = 1, 4 do
        local bg = display.newImageRect("FOTO/FonLvl.png", screenW, screenH)
        bg.anchorX = 0
        bg.x = (i - 3) * screenW
        bg.y = display.contentHeight - bg.height + 375
        bg:toBack()
        if gameGroup then gameGroup:insert(bg) end
        backgrounds[i] = bg
    end

    accumulatedOffset = 0

    bgTimer = timer.performWithDelay(16, function()
        if not isGameActive then return end
        accumulatedOffset = accumulatedOffset + scrollSpeed * 0.016
        local move = math.floor(accumulatedOffset)
        if move == 0 then return end
        accumulatedOffset = accumulatedOffset - move

        for i = 1, 4 do
            if backgrounds[i] then
                backgrounds[i].x = backgrounds[i].x - move
            end
        end

        for i = 1, 4 do
            if backgrounds[i] and backgrounds[i].x + backgrounds[i].width < 0 then
                local maxX = -math.huge
                for j = 1, 4 do
                    if backgrounds[j] and backgrounds[j].x > maxX then
                        maxX = backgrounds[j].x
                    end
                end
                backgrounds[i].x = maxX + screenW
            end
        end

        for i = 1, 4 do
            if backgrounds[i] then
                backgrounds[i].x = math.floor(backgrounds[i].x + 0.5)
            end
        end
    end, 0)

    table.insert(gameTimers, bgTimer)
end

-- Земля и игрок
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

-- Спавн объектов по уровням
local function startLevel1Spawning()
    local function spawnFriendly()
        if not isGameActive or not ground then return end
        local friendly = createFriendlySprite(display.contentWidth, ground.y)
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
    
    local spawnTimer = timer.performWithDelay(3000, spawnFriendly, 0)
    table.insert(gameTimers, spawnTimer)
end

local function startLevel2Spawning()
    local function spawnMixed()
        if not isGameActive or not ground then return end
        local isBandit = (math.random() > 0.5)
        if isBandit then
            local bandit = createBanditSprite(display.contentWidth, ground.y)
            bandit:setLinearVelocity(-200, 0)
            gameGroup:insert(bandit)
            table.insert(gameObjects, bandit)
        else
            local friendly = createFriendlySprite(display.contentWidth, ground.y)
            friendly:setLinearVelocity(-200, 0)
            gameGroup:insert(friendly)
            table.insert(gameObjects, friendly)
        end
    end
    
    local spawnTimer = timer.performWithDelay(3000, spawnMixed, 0)
    table.insert(gameTimers, spawnTimer)
end

local function startLevel3Features()
    shootButton = widget.newButton{
        label = "Огонь",
        x = display.contentWidth - 80,
        y = display.contentHeight - 80,
        width = 100, height = 60,
        onPress = function()
            if not isGameActive or not player then return end
            if _G.sounds.shoot then audio.play(_G.sounds.shoot) end
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
    
    local function enemyShoot(bandit)
        if not isGameActive or not bandit or not bandit.x or bandit.x < 0 then return end
        local ebullet = display.newImageRect("FOTO/bullet2.png", 50, 24)
        ebullet.x = bandit.x - 30
        ebullet.y = (bandit.groundY or display.contentHeight - 50) - 40
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
                local st = timer.performWithDelay(1500, function()
                    if obj and obj.x then
                        enemyShoot(obj)
                    end
                end, 0)
                obj.shootTimer = st
                table.insert(gameTimers, st)
            end
        end
    end
    local checkTimer = timer.performWithDelay(3000, addShootToBandit, 0)
    table.insert(gameTimers, checkTimer)
end

-- Обработка коллизий
local function onCollision(event)
    if not isGameActive then return end
    local obj1, obj2 = event.object1, event.object2
    if event.phase ~= "began" then return end
    
    if (obj1.ID == "player" and obj2.ID) or (obj2.ID == "player" and obj1.ID) then
        local other = (obj1.ID == "player") and obj2 or obj1
        if other.ID == "friendly" then
            lives = lives - 1
            if _G.sounds.hit then audio.play(_G.sounds.hit) end
            if other and other.removeSelf then other:removeSelf() end
            if gameOverlay and gameOverlay.livesText then gameOverlay.livesText.text = "Жизни: " .. lives end
            flashPlayer()
            shakeScreen()
            checkLose()
        elseif other.ID == "bandit" then
            score = score + 1
            if _G.sounds.point then audio.play(_G.sounds.point) end
            createExplosion(other.x, other.y)
            showScorePopup(other.x, other.y)
            if other.shootTimer then 
                timer.cancel(other.shootTimer)
                other.shootTimer = nil
            end
            if other and other.removeSelf then other:removeSelf() end
            if gameOverlay and gameOverlay.scoreText then gameOverlay.scoreText.text = "Очки: " .. score end
            if timeExpired then tryWin() end
        end
    end
    
    if obj1.ID == "playerBullet" or obj2.ID == "playerBullet" then
        local bullet = (obj1.ID == "playerBullet") and obj1 or obj2
        local target = (obj1.ID == "playerBullet") and obj2 or obj1
        if target.ID == "bandit" then
            score = score + 1
            if _G.sounds.point then audio.play(_G.sounds.point) end
            createExplosion(target.x, target.y)
            showScorePopup(target.x, target.y)
            if target.shootTimer then 
                timer.cancel(target.shootTimer)
                target.shootTimer = nil
            end
            if target and target.removeSelf then target:removeSelf() end
            if bullet and bullet.removeSelf then bullet:removeSelf() end
            if gameOverlay and gameOverlay.scoreText then gameOverlay.scoreText.text = "Очки: " .. score end
            if timeExpired then tryWin() end
        elseif target.ID == "friendly" then
            lives = lives - 1
            if _G.sounds.hit then audio.play(_G.sounds.hit) end
            if target and target.removeSelf then target:removeSelf() end
            if bullet and bullet.removeSelf then bullet:removeSelf() end
            if gameOverlay and gameOverlay.livesText then gameOverlay.livesText.text = "Жизни: " .. lives end
            flashPlayer()
            shakeScreen()
            checkLose()
        elseif target.ID == "enemyBullet" then
            if bullet and bullet.removeSelf then bullet:removeSelf() end
            if target and target.removeSelf then target:removeSelf() end
        end
    end
    
    if (obj1.ID == "enemyBullet" and obj2.ID == "player") or (obj2.ID == "enemyBullet" and obj1.ID == "player") then
        lives = lives - 1
        if _G.sounds.hit then audio.play(_G.sounds.hit) end
        if obj1.ID == "enemyBullet" then
            if obj1 and obj1.removeSelf then obj1:removeSelf() end
        else
            if obj2 and obj2.removeSelf then obj2:removeSelf() end
        end
        if gameOverlay and gameOverlay.livesText then gameOverlay.livesText.text = "Жизни: " .. lives end
        flashPlayer()
        shakeScreen()
        checkLose()
    end
end

local function jump(event)
    if event.phase == "began" and isGameActive and canJump and player then
        local vx, vy = player:getLinearVelocity()
        if vy and vy == 0 then
            player:setLinearVelocity(vx or 0, -500)
            if _G.sounds.jump then audio.play(_G.sounds.jump) end
            animateJump()
            canJump = false
            timer.performWithDelay(500, function() canJump = true end)
        end
    end
end

local function cleanupGame()
    if gameGroup then
        gameGroup:removeSelf()
        gameGroup = nil
    end
    for _, tid in ipairs(gameTimers) do 
        if tid then timer.cancel(tid) end
    end
    gameTimers = {}
    gameObjects = {}
    bullets = {}
    enemyBullets = {}
    if player and player.removeSelf then player:removeSelf() end
    player = nil
    ground = nil
    for i = 1, #backgrounds do
        if backgrounds[i] and backgrounds[i].removeSelf then backgrounds[i]:removeSelf() end
    end
    backgrounds = {}
    if bgTimer then timer.cancel(bgTimer); bgTimer = nil end
    if shootButton and shootButton.removeSelf then shootButton:removeSelf() end
    shootButton = nil
    isGameActive = false
    winTriggered = false
    timeExpired = false
    accumulatedOffset = 0
end

function scene:create(event)
    local params = event.params
    if params and params.level then
        level = params.level
    else
        level = 1
    end
    lives = 3
    score = 0
    timeLeft = levelDuration[level]
    isGameActive = true
    canJump = true
    winTriggered = false
    timeExpired = false
    
    physics.start()
    physics.setGravity(0, 20)
    
    gameGroup = display.newGroup()
    self.view:insert(gameGroup)
    
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
    local timerText = display.newText("Время: " .. timeLeft, display.contentWidth - 200, 20, native.systemFont, 25)
    timerText:setFillColor(1,1,1)
    gameOverlay:insert(timerText)
    gameOverlay.livesText = livesText
    gameOverlay.scoreText = scoreText
    gameOverlay.timerText = timerText
    gameGroup:insert(gameOverlay)
    
    createScrollingBackground()
    createGroundAndPlayer()
    
    if level == 1 then
        startLevel1Spawning()
    elseif level == 2 then
        startLevel2Spawning()
    elseif level == 3 then
        startLevel2Spawning()
        startLevel3Features()
    end

    gameGroup:insert(gameOverlay)
    
    local countdownTimer = timer.performWithDelay(1000, function()
        if not isGameActive or winTriggered then return end
        if timeLeft > 0 then
            timeLeft = timeLeft - 1
            if gameOverlay and gameOverlay.timerText then
                gameOverlay.timerText.text = "Время: " .. timeLeft
            end
        end
        if timeLeft <= 0 and not timeExpired then
            timeExpired = true
            if gameOverlay and gameOverlay.timerText then
                if level == 1 then
                    gameOverlay.timerText.text = "Время вышло!"
                else
                    gameOverlay.timerText.text = "Условия с временем выполнено"
                end
            end
        end
        tryWin()
        checkLose()
    end, 0)
    table.insert(gameTimers, countdownTimer)
    
    local function updateObjects()
        if not isGameActive then return end
        for i=#gameObjects,1,-1 do
            local obj = gameObjects[i]
            if obj and obj.x and (obj.x < -100 or obj.x > display.contentWidth+100) then
                if obj.shootTimer then timer.cancel(obj.shootTimer) end
                if obj and obj.removeSelf then obj:removeSelf() end
                table.remove(gameObjects, i)
            end
        end
        for i=#bullets,1,-1 do
            local b = bullets[i]
            if b and b.x and (b.x > display.contentWidth+50 or b.x < -50) then
                if b and b.removeSelf then b:removeSelf() end
                table.remove(bullets, i)
            end
        end
        for i=#enemyBullets,1,-1 do
            local eb = enemyBullets[i]
            if eb and eb.x and (eb.x > display.contentWidth+50 or eb.x < -50) then
                if eb and eb.removeSelf then eb:removeSelf() end
                table.remove(enemyBullets, i)
            end
        end
    end
    local frameTimer = timer.performWithDelay(50, updateObjects, 0)
    table.insert(gameTimers, frameTimer)
end

function scene:show(event)
    if event.phase == "did" then
        Runtime:addEventListener("touch", jump)
        Runtime:addEventListener("collision", onCollision)
    end
end

function scene:hide(event)
    if event.phase == "will" then
        Runtime:removeEventListener("touch", jump)
        Runtime:removeEventListener("collision", onCollision)
        cleanupGame()
    end
    if event.phase == "did" then
        composer.removeScene("game")
    end
end

function scene:destroy(event)
    cleanupGame()
end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene