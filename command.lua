local CHANNEL = 2828
local PROTOCOL = "H.O.M.U.CONTROL"

rednet.open(peripheral.getName(peripheral.find("modem", function (_, modem)
        return modem.isWireless()
end)))
rednet.CHANNEL_BROADCAST = CHANNEL

parallel.waitForAll(function ()
        while true do
                local id, message = rednet.receive(PROTOCOL)
                term.setTextColor(colors.yellow)
                print("[Receieved message] "..message.." from "..id)
                term.setTextColor(colors.white)
                if message == "r" then
                        rednet.send(id, "Rebooting...", PROTOCOL)
                        os.reboot()
                end
        end
end, function ()
        while true do
                rednet.broadcast(read(), PROTOCOL)
        end        
end)
