local files = {
        "/click.dfpwm",
        "/lettering.dfpwm",
        "/sending.dfpwm",
        "/sonar_ping.dfpwm",
        "/warning.dfpwm",
        "/graphics.lua",
        "/portal_manager.lua",
        "/setup.lua",
        "/startup.lua",
        "/installer.lua",
        "/utils.lua",
}

local function input()
        print("Enter name/repo")
        return "https://github.com/"..read().."/raw/refs/heads/main"
end

function update(address)
        local address = address or input()
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

function updateAll()
        local address = input()
        rednet.open()
        rednet.CHANNEL_BROADCAST = CHANNEL
        rednet.broadcast({
                action = "update",
                address = address
        }, PROTOCOL)
end