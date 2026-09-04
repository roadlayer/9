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
        "/command.lua"
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

local keyword = arg[1]
local address = "https://github.com/"..arg[2].."/raw/refs/heads/main"

if keyword == "i" then
        install(address)
end