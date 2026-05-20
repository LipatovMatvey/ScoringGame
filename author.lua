-- author.lua
local composer = require("composer")
local widget = require("widget")
local audio = require("audio")

local scene = composer.newScene()

-- Глобальные звуки и музыка
if not _G.sounds then
    _G.sounds = {}
end
_G.currentMusicFile = _G.currentMusicFile or nil
_G.bgMusicChannel = _G.bgMusicChannel or nil

local musicFiles = {
    "MUSIC/FonMusic.mp3",
    "MUSIC/FonMusic2.mp3",
    "MUSIC/FonMusic3.mp3",
    "MUSIC/FonMusic4.mp3"
}

local function loadSound(filename)
    local path = system.pathForFile(filename)
    if path then return audio.loadSound(filename) end
    return nil
end

-- Загружаем звуки только один раз за всё время работы приложения
if not _G.soundsLoaded then
    _G.sounds.jump   = loadSound("MUSIC/jump.wav")
    _G.sounds.shoot  = loadSound("MUSIC/shoot.wav")
    _G.sounds.hit    = loadSound("MUSIC/hit.wav")
    _G.sounds.point  = loadSound("MUSIC/point.wav")
    _G.sounds.win    = loadSound("MUSIC/win.wav")
    _G.sounds.lose   = loadSound("MUSIC/lose.wav")
    _G.soundsLoaded = true
    --print("Звуки загружены один раз")
end

function _G.playRandomMusic(avoidCurrent)
    if _G.bgMusicChannel then
        audio.stop(_G.bgMusicChannel)
        _G.bgMusicChannel = nil
    end
    local randomIndex
    if avoidCurrent and _G.currentMusicFile then
        local currentIndex
        for i, file in ipairs(musicFiles) do
            if file == _G.currentMusicFile then
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
    _G.currentMusicFile = newMusicFile
    local bgMusic = audio.loadStream(newMusicFile)
    if bgMusic then
        _G.bgMusicChannel = audio.play(bgMusic, { loops = -1 })
    end
end

function _G.stopMusic()
    if _G.bgMusicChannel then
        audio.stop(_G.bgMusicChannel)
        _G.bgMusicChannel = nil
    end
end

function scene:create(event)
    local group = self.view

    local bg = display.newImageRect("FOTO/FonStartWindow.png", display.contentWidth, display.contentHeight)
    bg.x, bg.y = display.contentCenterX, display.contentCenterY
    group:insert(bg)

    local title = display.newText("ШАШКИ МАНЕ", display.contentCenterX, 100, native.systemFont, 44)
    title:setFillColor(1, 1, 0)
    group:insert(title)

    local author = display.newText("Автор: Липатов Матвей 24ВП2", display.contentCenterX, 170, native.systemFont, 22)
    author:setFillColor(1, 1, 1)
    group:insert(author)

    local startBtn = widget.newButton{
        label = "Начать игру",
        x = display.contentCenterX, y = display.contentCenterY + 60,
        width = 220, height = 60,
        onPress = function()
            composer.gotoScene("menu")
        end
    }
    group:insert(startBtn)

    local musicBtn = widget.newButton{
        label = "Сменить музыку",
        x = display.contentCenterX, y = display.contentCenterY + 140,
        width = 220, height = 50,
        onPress = function()
            _G.playRandomMusic(true)
        end
    }
    group:insert(musicBtn)
end

function scene:show(event)
    if event.phase == "did" then
        _G.playRandomMusic()
    end
end

function scene:hide(event) end
function scene:destroy(event) end

scene:addEventListener("create", scene)
scene:addEventListener("show", scene)
scene:addEventListener("hide", scene)
scene:addEventListener("destroy", scene)

return scene