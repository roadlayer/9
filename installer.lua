local files = {
        "/click.dfpwm",
        "/lettering.dfpwm",
        "/sending.dfpwm",
        "/sonar_ping.dfpwm",
        "/warning.dfpwm",
        "/reveal.dfpwm",
        "/graphics.lua",
        "/portal_manager.lua",
        "/setup.lua",
        "/startup.lua",
        "/installer.lua",
        "/utils.lua",
}



function install(address)
        for _, path in pairs(files) do
                if fs.exists(path) then
                        fs.delete(path)
                end
                shell.run("wget "..address..path)
        end
        os.reboot()
end

local CHANNEL = 2828
local PROTOCOL = "H.O.M.U"

function updateOthers(address)
        rednet.open(peripheral.getName(peripheral.find("modem", function (_, modem)
                return modem.isWireless()
        end)))
        rednet.CHANNEL_BROADCAST = CHANNEL
        rednet.broadcast({
                update = true,
                usernamerepo = address
        }, PROTOCOL)
end

local keyword = arg[1]
local address = "https://github.com/"..arg[2].."/raw/refs/heads/main"

if keyword == "install" then
        install(address)
end