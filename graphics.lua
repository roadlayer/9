local utils = require("utils")

local Colors = {
        colors.white,
        colors.orange,
        colors.magenta,
        colors.lightBlue,
        colors.yellow,
        colors.lime,
        colors.pink,
        colors.gray,
        colors.lightGray,
        colors.cyan,
        colors.purple,
        colors.blue,
        colors.brown,
        colors.green,
        colors.red,
        colors.black
}

local graphics = {
        changePaletteColor = function (monitors, old, new_hex)
                for _, monitor in pairs(monitors) do
                        monitor.setPaletteColor(old, new_hex)
                end
        end,
        write = function (monitor, text, x, y, bg, fg)
                monitor.setCursorPos(x, y)
                monitor.setBackgroundColor(bg)
                monitor.setTextColor(fg)
                monitor.write(text)
        end,
        roll = function(monitors, charArray, x, y, width, fg_blit, bg_blit, reverse)
                for _, monitor in pairs(monitors) do
                        monitor.setCursorPos(x, y)
                        local currentX
                        for char = 1, #charArray do
                                currentX = monitor.getCursorPos()
                                if currentX <= width then
                                        monitor.blit(charArray[char], fg_blit, bg_blit)
                                else
                                        monitor.setCursorPos(currentX - width, y)
                                        monitor.blit(charArray[char], fg_blit, bg_blit)
                                end
                        end
                end
                if reverse then
                        if x == 1 then
                                x = width
                        else
                                x = x - 1
                        end
                elseif x == width then
                        x = 1
                else
                        x = x + 1
                end
                return x
        end,
        addButton = function (monitor, text, x, y, fg, bg, padding)
                local label = text
                if padding then
                        local label = padding..text..padding
                end
                label, fg, bg = utils.blitText(label, fg, bg)
                local x1 = x
                monitor.setCursorPos(x, y)
                monitor.blit(label, fg, bg)
                -- local x2, y2 = monitor.getCursorPos() <<<< this will probably fail
                local x2 = x1 + #label -- just assume single line
                return {
                        side = monitor.name,
                        text = text,
                        x1 = x1,
                        x2 = x2,
                        y = y,
                }
        end,
        checkButtonPress = function (touch, button) -- <<<< technically not graphics related but ton
                if button.side == touch.side then
                        if touch.y == button.y then
                                if touch.x >= button.x1 and touch.x < button.x2 then
                                        if button.active then
                                                return button
                                        end
                                end
                        end
                end
        end,
        fillLine = function (monitors, symbol, x, y, length, fg, bg)
                local text = string.rep(symbol, length)
                text, fg, bg = utils.blitText(text, fg, bg)
                for _, monitor in pairs(monitors) do
                        monitor.setCursorPos(x, y)
                        monitor.blit(text, fg, bg)
                end
        end,
        writeRoll = function (self, monitor, charArray, x, y, bg, fg, inverted)
                local maxX = monitor.getSize()
                monitor.setCursorPos(x, y)
                local shift = 0

                if not inverted then
                        self.write(monitor, "_", x, y, bg, bg) -- draw blank
                        x = utils.loopingIterator(x, 1, maxX)
                end

		for char = 1, #charArray do
                        self.write(monitor, charArray[char], x, y, bg, fg)
                        x = utils.loopingIterator(x, 1, maxX)
		end

                if inverted then
                        self.write(monitor, "_", x, y, bg, bg) -- draw blank
                        x = utils.loopingIterator(x, 1, maxX)
                        shift = -2
                end

                return utils.loopingIterator(x, -#charArray+shift, maxX)
        end,
        splash = function (monitor, bg)
                monitor.setBackgroundColor(bg)
                monitor.clear()
        end,
        getCenter = function (monitor, text)
                local x, y = monitor.getSize()
                local shift = 0
                if text ~= nil then
                        shift = #text
                end
                x = math.floor((x - shift) / 2) + 1
                y = math.floor(y / 2) + 1
                return x, y
        end,
        clearAll = function (monitors)
                for _, monitor in pairs(monitors or {peripheral.find("monitor")}) do
                        monitor.setBackgroundColor(colors.black)
                        monitor.clear()
                end
        end,
        fillWithSymbol = function (self, monitor, symbol, fg, bg)
                local width, height = monitor.getSize()
                local string = string.rep(symbol, width)
                for y = 1, height do
                        self.write(monitor, string, 1, y, bg, fg)
                end
        end,
        updatePalette = function (monitors, color, new_color)
                for _, monitor in pairs(monitors) do
                        monitor.setPaletteColor(color, new_color)
                end
        end,
        drawSquare = function (monitors, corners, fg_blit)
                local width = corners[2].x - corners[1].x
                local height = corners[3].y - corners[1].y
                local blit_string = string.rep(fg_blit, width)
                for _, monitor in pairs(monitors) do
                        monitor.setCursorPos(corners[1].x, corners[1].y)
                        monitor.blit(blit_string, blit_string, blit_string)
                        monitor.setCursorPos(corners[3].x, corners[3].y)
                        monitor.blit(blit_string, blit_string, blit_string)
                        for y = corners[1].y, corners[3].y do
                                monitor.setCursorPos(corners[1].x, y)
                                monitor.blit(fg_blit, fg_blit, fg_blit)
                                monitor.setCursorPos(corners[2].x, y)
                                monitor.blit(fg_blit, fg_blit, fg_blit)
                        end
                end
        end
}

graphics.Button = {
        draw = function (self)
                local m = self.monitor
                local x, y = self.x, self.y
                local padding = self.padding
                local text = padding..self.text..padding
                local fg, bg = self.fg, self.bg
                graphics.fillLine({m}, " ", x, y, self.width, colors.white, colors.white)
                sleep(0.1)
                graphics.fillLine({m}, " ", x, y, self.width, colors.black, colors.black)
                sleep(0.1)
                graphics.addButton(m, text, x, y, fg, bg, padding)
                self.isActive = true
        end,
        delete = function (self)
                local m = self.monitor
                local x, y = self.x, self.y
                local padding = self.padding
                local text = padding..self.text..padding
                local fg, bg = self.fg, self.bg
                graphics.fillLine({m}, " ", x, y, self.width, colors.white, colors.white)
                sleep(0.1)
                graphics.fillLine({m}, " ", x, y, self.width, colors.black, colors.black)
                sleep(0.1)
                self.isActive = false
        end,
        update = function (self, touch)
                local side = touch.side
                local x = touch.x
                local y = touch.y
                if side == self.side then
                        if x >= self.x and x < (self.x + self.width) then
                                if y == self.y and self.isActive then
                                        self:action()
                                end
                        end
                end
        end
}

function graphics.Button.new(monitor, text, x, y, fg, bg, padding, action)
        local button = {
                monitor = monitor,
                side = peripheral.getName(monitor),
                text = text,
                x = x, y = y,
                fg = fg, bg = bg,
                padding = padding,
                width = #text + (#padding)*2,
                action = action
        }
        setmetatable(button, {__index = graphics.Button})
        return button
end

return graphics