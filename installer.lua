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
        rednet.open()
        rednet.CHANNEL_BROADCAST = CHANNEL
        rednet.broadcast({
                update = true,
                address = address
        }, PROTOCOL)
end

local keyword = arg[1]

if keyword == "update" then
        update(input())
elseif keyword == "updateAll" then
        updateOthers(input())
end