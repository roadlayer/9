local utils = require("utils")
local setup = require("setup")
local graphics = require("graphics")
local Button = require("graphics").Button

TICKRATE = 0.4

local CurrentState

local function log(text, color)
        term.setTextColor(color or colors.white)
        if CurrentState then
                print("["..(CurrentState.name or "?").."] "..text)
        end
end

local m, board = {}, {}
local innerArray
local ring

local W = {
        activated = false,
        arrayInUse = false,
        ready = false,
        playersInside = {},
        lastTouch = nil,
        playersElsewhere = false,
        destinations = {},
        destination,
        isDestinationReady = false,
        cellInside = false,
        selectedAsDestination = false,
        innerIdle = {
                isRunning = false,
                isUpdated = false,
                text,
                color = colors.white,
        },
        outerIdle = {
                isRunning = false,
                text,
                color = colors.white,
        },
        randomSplash = {
                isRunning = false,
        },
        squareFade = {
                isRunning = false
        },
        attachedPeripheral = false,
        buttons = {},
        nodesReady = 0,
        nodeInUse,
}
local DEFAULTS = W

local sio_port = {
        activate = function (wait)
                if not W.activated then
                        log("Spatial IO Port activated")
                        redstone.setAnalogOutput("top", 1)
                        sleep(wait or 0.1)
                        redstone.setAnalogOutput("top", 0)
                        W.activated = true
                end
        end,
        importCell = function ()
                local bridge = peripheral.wrap("front")
                while #peripheral.wrap("top").list() < 1 do
                        bridge.exportItem({count = 1}, "top")
                        log("failed")
                        sleep(0.05)
                end
        end
}

local CHANNEL = 2828
local PROTOCOL = "H.O.M.U"

local Listener = {
        getPlayersInside = function ()
                local detector = peripheral.find("player_detector")
                sleep(0.5) -- <<<< throttle
                return detector.getPlayersInCubic(2, 5, 2)
        end,
        peripheralDetector = function (wait_sec)
                if wait_sec then
                        sleep(wait_sec)
                end
                local event, side = os.pullEvent("peripheral")
                W.attachedPeripheral = true
                return side
        end,
        rednet = function ()
                rednet.open(peripheral.getName(peripheral.find("modem", function (_, modem)
                        return modem.isWireless()
                end)))
                rednet.CHANNEL_BROADCAST = CHANNEL
                log("Connected to rednet on channel "..rednet.CHANNEL_BROADCAST, colors.red)
                while true do
                        local id, message = rednet.receive(PROTOCOL)
                        -------------- Destinations --------------
                        if message == "ping" then -- <<<< signal to go busy
                                local pong = {
                                        id = settings.get("id"),
                                        name = settings.get("portal_name")
                                }
                                rednet.send(id, pong, PROTOCOL)
                                W.nodeInUse = id
                                W.arrayInUse = true
                        elseif type(message) == "table" then -- <<<< receive pong
                                if message.id then
                                        table.insert(W.destinations, message)
                                        log("Destination added: "..message.id.." - "..message.name)
                        ------------------------------------------
                                elseif message.update then
                                        shell.run("installer install "..message.usernamerepo)
                                end
                        elseif message == "get_ready" then
                                W.selectedAsDestination = true
                        elseif message == "finished" then
                                os.reboot() -- <<<< my best implementation of the garbage collector
                        elseif message == "proceed" then
                                W.nodesReady = W.nodesReady + 1
                        elseif message == "aborted" then
                                W.arrayInUse = false
                        end
                end
        end,
        touchInput = function ()
                log("Listening for touch events")
                while true do
                        W.lastTouch = {os.pullEvent("monitor_touch")}
                end
        end,
        getTouchInput = function ()
                if W.lastTouch then
                        local lastTouch = {
                                side = W.lastTouch[2],
                                x = W.lastTouch[3],
                                y = W.lastTouch[4]
                        }
                        W.lastTouch = nil
                        return lastTouch
                end
        end,
        getAttachedPeripheral = function (self, wait)
                local side = self.peripheralDetector(wait)
                W.attachedPeripheral = false
                return side
        end
}

local hatch = {
        open = function (self)
                log("Opening the hatch")
                redstone.setOutput("bottom", false)
                Listener:getAttachedPeripheral(0.5)
                sleep(0.15)
                W.isOpen = true
        end,
        close = function (self)
                log("Closing the hatch")
                redstone.setOutput("bottom", true)
                Listener:getAttachedPeripheral(0.5)
                sleep(0.15)
                W.isOpen = false
        end
}

function W.updateBoardValues(text, color)
        W.outerIdle.text = text
        W.outerIdle.color = color
        W.outerIdle.isUpdated = true
end

local audio = {
        sound = {
                sending = "/sending.dfpwm",
                warning = "/warning.dfpwm",
                click = "/click.dfpwm",
                lettering = "/lettering.dfpwm",
                reveal = "/reveal.dfpwm",
                sonar_ping = "/sonar_ping.dfpwm"
        },
        playSfx = function (sound, volume)
                local speaker = peripheral.find("speaker")
                log("Playing "..sound, colors.yellow)
                for chunk in io.lines(sound, 16 * 1024) do
                        local buffer = utils.decoder(chunk)
                        while not speaker.playAudio(buffer, volume or 3) do
                                os.pullEvent("speaker_audio_empty")
                        end
                end
        end,
        stop = function ()
                local speaker = peripheral.find("speaker")
                speaker.stop()
        end
}
local animation = {
        slowWrite = function (monitor, text, x, y, bg, fg, rate)
                local charArray = utils.textToArray(text)
                audio.playSfx(audio.sound.lettering, 0.1)
                for char = 1, #charArray do
                        graphics.write(monitor, charArray[char], x, y, bg, fg)
                        x = x + 1
                        sleep(rate or 0.05)
                end
                audio.stop(); sleep(0.1)
        end,
        innerIdle = function ()
                W.innerIdle.isRunning = true
                W.innerIdle.isUpdated = true
                local text, fg, bg, fg_blit, bg_blit, x1, x2, y1, y2, charArray
                local width, height = m.front.getSize()
                local x = graphics.getCenter(m.front, W.innerIdle.text)
                while W.innerIdle.isRunning do
                        if W.innerIdle.isUpdated then
                                W.innerIdle.isUpdated = false
                                text = W.innerIdle.text
                                fg = colors.black
                                bg = W.innerIdle.color
                                x1, y1 = x, 1     --- top cursor
                                x2, y2 = x, height  --- bottom cursor
                                charArray = utils.textToArray(" "..text.." ")
                                fg_blit, bg_blit = colors.toBlit(fg), colors.toBlit(bg)

                                graphics.splash(m.top, colors.lightGray)
                                graphics.splash(m.bottom, colors.lightGray)
                                graphics.fillLine(ring, " ", 1, y1, width, colors.lightGray, colors.lightGray)
                                graphics.fillLine(ring, " ", 1, y2, width, colors.lightGray, colors.lightGray)
                                sleep(0.1)

                                graphics.splash(m.top, colors.black)
                                graphics.splash(m.bottom, colors.black)
                                graphics.fillLine(ring, " ", 1, y1, width, colors.black, colors.black)
                                graphics.fillLine(ring, " ", 1, y2, width, colors.black, colors.black)
                                sleep(0.1)

                                graphics.splash(m.top, bg)
                                graphics.splash(m.bottom, bg)
                                graphics.fillLine(ring, " ", 1, y1, width, bg, bg)
                                graphics.fillLine(ring, " ", 1, y2, width, bg, bg)
                        end
                        x1 = graphics.roll(ring, charArray, x1, y1, width, fg_blit, bg_blit)
                        x2 = graphics.roll(ring, charArray, x2, y2, width, fg_blit, bg_blit, true)
                        sleep(0.2)
                end
        end,
        outerIdle = function ()
                while not W.outerIdle.isRunning do
                        sleep(0.5)
                end
                W.outerIdle.isUpdated = true
                local text, symbol, fg, bg, fg_blit, bg_blit, charArray
                local width, height = board.getSize()
                local x = graphics.getCenter(board, W.outerIdle.text)
                while W.outerIdle.isRunning do
                        if W.outerIdle.isUpdated then
                                W.outerIdle.isUpdated = false
                                text = W.outerIdle.text
                                fg, bg = W.outerIdle.color, colors.black
                                board.clear()
                                symbol = string.char(127)
                                
                                x = graphics.getCenter(board, text)
                                fg_blit, bg_blit = colors.toBlit(fg), colors.toBlit(bg)
                                charArray = utils.textToArray(" "..text.." ")

                                graphics.splash(board, fg)
                                graphics.write(board, text, x, 1, fg, bg)
                                graphics.fillLine({board}, symbol, 1, 2, width, bg, fg)
                                sleep(0.2)
                                graphics.splash(board, bg)
                                graphics.fillLine({board}, symbol, 1, 2, width, fg, bg)
                        end
                        x = graphics.roll({board}, charArray, x, 1, width, fg_blit, bg_blit, true)
                        sleep(0.15)
                end
        end,
        squareFade = function (monitors, color, reverse, once, pause, mult)
                W.squareFade.isRunning = true
                local pause = pause or 0.1
                local mult = mult or 1
                while W.squareFade.isRunning do
                        local fg = colors.toBlit(color)
                        local fg2 = colors.toBlit(colors.black)
                        local width, height = m.top.getSize()
                        if not reverse then
                                local corners = {
                                        { x = 1,     y = 1 },      -- top left
                                        { x = width, y = 1 },      -- top right
                                        { x = 1,     y = height }, -- bottom left
                                        { x = width, y = height }  -- bottom right
                                }
                                repeat
                                        graphics.drawSquare(monitors, corners, fg)
                                        sleep(pause)
                                        graphics.drawSquare(monitors, corners, fg2)
                                        corners = {
                                                { x = corners[1].x + 1, y = corners[1].y + 1 }, -- top left
                                                { x = corners[2].x - 1, y = corners[2].y + 1 }, -- top right
                                                { x = corners[3].x + 1, y = corners[3].y - 1 }, -- bottom left
                                                { x = corners[4].x - 1, y = corners[4].y - 1 }  -- bottom right
                                        }
                                until corners[1].y > corners[3].y
                        else
                                local x, y = graphics.getCenter(m.top, "##########")
                                local corners = {
                                        { x = x,     y = y }, -- top left
                                        { x = x + 10, y = y }, -- top right
                                        { x = x,     y = y }, -- bottom left
                                        { x = x + 10, y = y }  -- bottom right
                                }
                                repeat
                                        graphics.drawSquare(monitors, corners, fg)
                                        sleep(pause)
                                        graphics.drawSquare(monitors, corners, fg2)
                                        corners = {
                                                { x = corners[1].x - 1, y = corners[1].y - 1 }, -- top left
                                                { x = corners[2].x + 1, y = corners[2].y - 1 }, -- top right
                                                { x = corners[3].x - 1, y = corners[3].y + 1 }, -- bottom left
                                                { x = corners[4].x + 1, y = corners[4].y + 1 }  -- bottom right
                                        }
                                until corners[1].y < 0
                        end
                        if once then break end
                        pause = pause*mult
                end
        end,
        moveHorizontalLine = function (monitor, fromTop, color, pause)
                local pause = pause or 0.1
                local step = 1
                local width, height = monitor.getSize()
                local y = 1
                if not fromTop then
                        step = -1
                        y, height = height, y
                end
                repeat
                        graphics.fillLine({monitor}, "_", 1, y, width, color, color)
                        sleep(pause)
                        graphics.fillLine({monitor}, "_", 1, y, width, colors.black, colors.black)
                        y = y + step
                until y == height      
        end,
        moveVerticalLine = function (monitor, fromLeft, color, pause)
                local pause = pause or 0.1
                local step = 1
                local width, height = monitor.getSize()
                local x = 1
                local fg_blit = colors.toBlit(color)
                local black_blit = colors.toBlit(colors.black)
                if not fromLeft then
                        step = -1
                        x, width = width, x
                end
                repeat
                        for y = 1, height do
                                monitor.setCursorPos(x, y)
                                monitor.blit(fg_blit, fg_blit, fg_blit)
                                monitor.setCursorPos(x, y)
                                monitor.blit(fg_blit, fg_blit, fg_blit)
                        end
                        sleep(pause)
                        for y = 1, height do
                                monitor.setCursorPos(x, y)
                                monitor.blit(black_blit, black_blit, black_blit)
                                monitor.setCursorPos(x, y)
                                monitor.blit(black_blit, black_blit, black_blit)
                        end
                        x = x + step
                until y == height
        end,
        paletteShift = function ()
                local step = 0.0105
                local x = 0
                while x <= 1 do
                        local channelA = utils.easeInPow(x, 10)
                        local channelB = 1 - channelA
                        graphics.updatePalette(m, colors.black, colors.packRGB(channelA, channelA, channelA))
                        x = x + step
                        sleep(0.05)
                end
        end,
        reception = function (self)
                local lines = {"Welcome To", " "..settings.get("portal_name").." "}
                local monitor = m.front
                local x, y = graphics.getCenter(m.front, lines[1])
                local fg, bg = colors.white, colors.black
                self.slowWrite(m.front, lines[1], x, y, bg, fg)
                monitor.scroll(1)
                x, y = graphics.getCenter(m.front, lines[2])
                fg, bg = colors.black, colors.white
                self.slowWrite(m.front, lines[2], x, y, bg, fg)
                fg, bg = colors.lime, colors.black
                monitor.setBackgroundColor(bg)
                for _, name in pairs(Listener.getPlayersInside()) do
                        monitor.scroll(1)
                        x, y = graphics.getCenter(monitor, name)
                        
                        self.slowWrite(monitor, name, x, y, bg, fg)
                end
        end,
        randomSplash = function ()
                while true do
                        while W.randomSplash.isRunning do
                                local monitor = utils:randomFromDictionary(m, "back", true)
                                graphics.splash(monitor, colors.magenta)
                                sleep(1)
                                if W.randomSplash.isRunning or monitor ~= m.front then
                                        graphics.splash(monitor, colors.black)
                                end
                        end
                        sleep(1)
                end
        end
}

local State
State = {
        init = {
                name = "INIT",
                color = colors.gray,
                enter = function (self, ...)
                        log("Welcome!", colors.lime)
                        setup:init()
                        m, board = setup:getMonitorPeripherals()
                        innerArray = { m.front, m.left, m.right, m.back, m.top, m.bottom }
                        ring = { m.front, m.left, m.right, m.back }
                        graphics.clearAll()
                        log("Setup complete")
                end,
                update = function (self, ...)
                        CurrentState = State.on_standby
                        
                end
        },
        on_standby = {
                name = "ON STANDBY",
                color = colors.magenta,
                enter = function (self, ...)
                        log("Waiting for players")
                        W.randomSplash.isRunning = true
                        W.outerIdle.isRunning = true
                end,
                update = function (self, ...)
                        --CurrentState = State.busy -- <<<< test
                        while self == CurrentState do sleep(TICKRATE)
                                if #Listener.getPlayersInside() > 0 then
                                        CurrentState = State.waiting
                                elseif W.arrayInUse then
                                        CurrentState = State.busy
                                end
                        end
                end,
        },
        waiting = {
                name = "WAITING",
                color = colors.yellow,
                enter = function (self, ...)
                        log("Waiting for player input")
                        
                end,
                update = function (self, text, x, y)
                        while self == CurrentState do sleep(0.05)
                                local touch = Listener.getTouchInput()
                                if touch and touch.side == m.front.name then
                                        CurrentState = State.in_use
                                end
                                if #Listener.getPlayersInside() == 0 then
                                        CurrentState = State.on_standby
                                        animation.slowWrite(m.front, text, x, y, colors.black, colors.black)
                                elseif W.arrayInUse then
                                        CurrentState = State.busy
                                end
                        end
                end
        },
        busy = {
                name = "BUSY",
                color = colors.red,
                enter = function (self)
                        log("Array is in use, waiting to be selected or for process to finish")
                        for _, monitor in pairs(m) do
                                local line1 = " NETWORK IS IN USE "
                                local line2 = " PLEASE EXIT THE CABIN "
                                local x1, y = graphics.getCenter(monitor, line1)
                                local x2 = graphics.getCenter(monitor, line2)
                                graphics:fillWithSymbol(monitor, string.char(127), colors.red, colors.black)
                                for i = y - 2, y + 1 do
                                        graphics.fillLine({monitor}, " ", x2, i, #line2, colors.red, colors.red)
                                end
                                graphics.write(monitor, line1, x1, y - 1, colors.red, colors.black)
                                graphics.write(monitor, line2, x2, y, colors.red, colors.black)
                        end
                        audio.playSfx(audio.sound.warning, 0.3)
                        while #Listener.getPlayersInside() > 0 do
                                sleep(0.05)
                        end
                        hatch.close()
                        rednet.send(W.nodeInUse, "proceed", PROTOCOL)
                        graphics.clearAll(m)
                        graphics.changePaletteColor(innerArray, colors.black, 0x000000)
                end,
                update = function (self)
                        while self == CurrentState do sleep(TICKRATE)
                                if W.selectedAsDestination then
                                        CurrentState = State.receiving
                                elseif not W.arrayInUse then
                                        hatch.open()
                                        CurrentState = State.on_standby
                                end
                        end
                end
        },
        in_use = {
                name = "IN USE",
                color = colors.orange,
                transitionIn = function (self)
                        graphics.clearAll(m)
                        log("Requesting destinations")
                        rednet.broadcast("ping", PROTOCOL)
                        hatch.close()
                        log("Waiting for other nodes to be ready")
                        while #W.destinations ~= W.nodesReady do
                                sleep(0.05)
                        end
                        m.front.clear()
                        graphics.changePaletteColor(innerArray, colors.black, 0x000000)
                        log("Beginning selection")
                end,
                enter = function (self)
                        W.innerIdle.text = "SELECT DESTINATION"
                        W.innerIdle.color = colors.blue
                        W.outerIdle.isUpdated = true
                        local x, y = 2, 3
                        local width, height = m.front.getSize()
                        local fg, bg = colors.white, colors.gray
                        audio.playSfx(audio.sound.reveal, 0.1)
                        W.buttons["abort"] = Button.new(m.front, "ABORT", x, height - 2, colors.black, colors.red, " ")
                        W.buttons["abort"].action = function ()
                                audio.playSfx(audio.sound.click)
                                W.buttons["abort"]:delete()
                                local text = " ABORTED "
                                W.innerIdle.text = text..string.rep(string.char(127), width - #text)
                                W.innerIdle.color = colors.red
                                W.innerIdle.isUpdated = true
                                rednet.broadcast("aborted", PROTOCOL)
                                sleep(0.5)
                                os.reboot()
                        end
                        for key, destination in pairs(W.destinations) do
                                W.buttons[destination.name] = Button.new(m.front, destination.name, x, y, fg, bg, " ")
                                W.buttons[destination.name].action = function (self) -- <<<< first press
                                        audio.playSfx(audio.sound.click)
                                        W.innerIdle.text = "CONFIRM?"
                                        W.innerIdle.color = colors.lime
                                        W.innerIdle.isUpdated = true
                                        W.buttons[destination.name]:delete()
                                        local confirmationButton = Button.new(self.monitor, self.text.."???", self.x, self.y, colors.black, colors.lime, " ")
                                        local cancelButton = Button.new(self.monitor, string.char(171), self.x - 1, self.y, colors.black, colors.red, "")
                                        for key2 in pairs(W.buttons) do
                                                if W.buttons[key2].isActive then
                                                        W.buttons[key2]:delete()
                                                end
                                        end
                                        W.buttons[destination.name] = confirmationButton
                                        W.buttons[destination.name]:draw()
                                        W.buttons[destination.name].action = function (self)
                                                audio.playSfx(audio.sound.click)
                                                W.buttons[destination.name]:delete()
                                                for key2 in pairs(W.buttons) do
                                                        if W.buttons[key2].isActive then
                                                                W.buttons[key2]:delete()
                                                        end
                                                end
                                                local text = " TO "..string.upper(destination.name).." "
                                                W.innerIdle.text = text..string.rep(string.char(62), width - #text)
                                                W.innerIdle.color = colors.lightGray
                                                W.innerIdle.isUpdated = true
                                                W.destination = destination.id
                                                log("Selected destination: "..destination.name)
                                        end
                                        W.buttons[destination.name.."_cancel"] = cancelButton
                                        W.buttons[destination.name.."_cancel"]:draw()
                                        W.buttons[destination.name.."_cancel"].action = function (self)
                                                audio.playSfx(audio.sound.click)
                                                W.buttons[destination.name.."_cancel"]:delete()
                                                for key2 in pairs(W.buttons) do
                                                        if W.buttons[key2].isActive then
                                                                W.buttons[key2]:delete()
                                                        end
                                                end
                                                W.innerIdle.isUpdated = true
                                                CurrentState.enter()
                                        end
                                end
                                W.buttons[destination.name]:draw()
                                x, y = 2, y + 2 -- <<<< i am actually trolling here
                        end
                        W.buttons["abort"]:draw()
                        audio.stop()
                end,
                update = function (self)
                        local fg = colors.white
                        while self == CurrentState do sleep(TICKRATE)
                                local touch = Listener.getTouchInput()
                                if touch then
                                        for key in pairs(W.buttons) do
                                                W.buttons[key]:update(touch)
                                        end
                                end
                                if W.aborted then
                                        CurrentState = State.on_standby
                                        hatch:open()
                                elseif W.destination then
                                        CurrentState = State.sending
                                end
                        end
                        W.isInnerIdleRunning = false
                end
        },
        sending = {
                name = "SENDING",
                color = colors.blue,
                enter = function (self)
                        log("Preparing to send")
                        local width, height = m.front.getSize()
                        W.outerIdle.isUpdated = true
                end,
                update = function (self)
                        while self == CurrentState do sleep(TICKRATE)
                                
                        end
                end
        },
        receiving = {
                name = "RECEIVING",
                color = colors.lime,
                enter = function (self)
                        log("Received")
                        sleep(3)
                        hatch.open()

                end
        }
}

local function run()
        CurrentState = State.init
        parallel.waitForAll( function (spawn) -- <<<< this is dogshit
                while true do sleep(TICKRATE)
                        if State.init == CurrentState then
                                CurrentState:enter()
                                spawn(Listener.touchInput)
                                spawn(Listener.rednet)
                                spawn(animation.outerIdle)
                                spawn(animation.randomSplash)
                                board.setTextScale(2.5)
                                sleep(1)
                                graphics.clearAll()
                                CurrentState:update()
                        elseif State.on_standby == CurrentState then
                                W = DEFAULTS
                                W.updateBoardValues(CurrentState.name, CurrentState.color)
                                graphics.clearAll()
                                m.front.setTextScale(1)
                                CurrentState:enter()
                                CurrentState:update()
                                W.randomSplash.isRunning = false
                        elseif State.waiting == CurrentState then
                                W.updateBoardValues(CurrentState.name, CurrentState.color)
                                local text = "TOUCH TO START"
                                local x, y = graphics.getCenter(m.front, "TOUCH TO START")
                                spawn(function ()
                                        graphics.splash(m.front, colors.black)
                                        animation.slowWrite(m.front, text, x, y, colors.black, colors.white)
                                end)
                                CurrentState:enter()
                                CurrentState:update(text, x, y)
                        elseif State.in_use == CurrentState then
                                spawn( function ()
                                        local fg = colors.white
                                        audio.playSfx(audio.sound.sonar_ping, 0.2)
                                        animation.squareFade({m.front}, fg, true, true)
                                        local text = "Waiting for network"
                                        local x, y = graphics.getCenter(m.front, text)
                                        graphics.write(m.front, text, x, y, colors.black, colors.lightGray)
                                end)
                                W.updateBoardValues(CurrentState.name, CurrentState.color)
                                CurrentState:transitionIn()
                                spawn( function ()
                                        sleep(0.1)
                                        animation.innerIdle()
                                end)
                                CurrentState:enter()
                                CurrentState:update()
                        elseif State.busy == CurrentState then
                                W.updateBoardValues(CurrentState.name, CurrentState.color)
                                CurrentState:enter()
                                CurrentState:update()
                        elseif State.sending == CurrentState then
                                W.updateBoardValues(CurrentState.name, CurrentState.color)
                                CurrentState:enter()
                                sio_port.importCell()
                                do -- <<<< animation transition has to be here
                                        W.innerIdle.isRunning = false
                                        audio.playSfx(audio.sound.reveal, 0.1)
                                        local width, height = m.front.getSize()
                                        graphics.splash(m.top, colors.white)
                                        graphics.splash(m.bottom, colors.white)
                                        graphics.fillLine(ring, " ", 1, 1, width, colors.white, colors.white)
                                        graphics.fillLine(ring, " ", 1, height, width, colors.white, colors.white)
                                        sleep(0.1)

                                        graphics.fillLine(ring, " ", 1, 1, width, colors.black, colors.black)
                                        graphics.fillLine(ring, " ", 1, height, width, colors.black, colors.black)
                                        sleep(0.1)
                                        audio.stop()
                                spawn(function () animation.squareFade({m.top, m.bottom}, colors.lightGray, false, true, 0.08) end)
                                end
                                rednet.send(W.destination, "get_ready", PROTOCOL) -- <<<< insert cell on the other side
                                spawn(function () 
                                        audio.stop(); sleep(0.1)
                                        audio.playSfx(audio.sound.sending) end)
                                spawn(function () animation.paletteShift() end)
                                sleep(5.1)
                                sio_port.activate()
                                sleep(0.3)
                                graphics.changePaletteColor(innerArray, colors.black, 0x111111)
                                CurrentState:update()
                        elseif State.receiving == CurrentState and not W.activated then
                                W.updateBoardValues(CurrentState.name, CurrentState.color)
                                sio_port.importCell()
                                sio_port.activate()
                                sleep(0.5)
                                spawn( function ()
                                        local fg = colors.lime
                                        animation.squareFade({m.back}, fg, true, true) end)
                                spawn(function ()
                                        animation:reception() end)
                                CurrentState:enter()
                                W.updateBoardValues("REBOOTING", colors.white)
                                rednet.broadcast("finished", PROTOCOL)
                                os.reboot()
                        end
                end
        end)
end

parallel.waitForAny( -- <<<< waiting for the door before running
        function ()
                sleep(3.5)
        end,
        function ()
                hatch.open()
        end)

run()