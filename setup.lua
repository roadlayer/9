local utils = require("utils")

local function getMonitorNames()
        local sides = { "front", "left", "right", "top", "bottom" }
        local monitors = {}
        local board = nil
        utils.log("Touch monitors in the following order:")
        utils.log(table.concat(sides, " "))
        for _, side in pairs(sides) do
                local _, touched_side = os.pullEvent("monitor_touch")
                monitors[side] = touched_side
                peripheral.call(touched_side, "setBackgroundColor", colors.lime)
                peripheral.call(touched_side, "clear")
                utils.log(touched_side.." saved as "..side)
        end

        utils.log("Finding back and board monitors..")
        local extras = {}
        for _, found in pairs({ peripheral.find("monitor") }) do
                local new = true
                local found_name = peripheral.getName(found)
                for _, saved_name in pairs(monitors) do
                        if found_name == saved_name then
                                new = false
                        end
                end
                if new then
                        table.insert(extras, found_name)
                end
        end
        local _, y1 = peripheral.call(extras[1], "getSize")
        local _, y2 = peripheral.call(extras[2], "getSize")
        if y1 > y2 then
                monitors.back = extras[1]
                board = extras[2]
        else
                monitors.back = extras[2]
                board = extras[1]
        end
        return monitors, board
end

local setup = {
        PATH = ".config",
        fields = {
                "portal_name",
                "id",
                "monitors",
                "board"
        },
        init = function (self)
                self:defineSettings()
                self:loadSettings()
                for i = 1, #self.fields do
                        if not settings.get(self.fields[i]) then
                                self:setSettings()
                                self:loadSettings()
                                break
                        end
                end
        end,
        defineSettings = function (self)
                for i = 1, #self.fields do
                        settings.define(self.fields[i])
                end
        end,
        loadSettings = function (self)
                settings.load(self.PATH)
                for _, value in pairs(self.fields) do
                        local setting = settings.get(value)
                        if not setting then break end
                end
        end,
        setSettings = function (self)
                utils.log("Enter the name of this location")
                settings.set(self.fields[1], read())
                settings.set(self.fields[2], os.getComputerID())
                local m, board = getMonitorNames()
                settings.set(self.fields[3], m)
                settings.set(self.fields[4], board)
                settings.save(self.PATH)
        end,
        getMonitorPeripherals = function (self)
                local monitors = settings.get(self.fields[3])
                for key, value in pairs(monitors) do
                        monitors[key] = peripheral.wrap(value)
                        monitors[key].name = value
                        monitors[key].setBackgroundColor(colors.lime)
                        monitors[key].clear()
                end
                local board = peripheral.wrap(settings.get(self.fields[4]))
                board.name = self.fields[4]
                return monitors, board
        end
}

return setup