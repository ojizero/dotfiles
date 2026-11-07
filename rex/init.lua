rex.bind("cmd+k", "com.superlogical.terminal.clear")

rex.bind("cmd+0", "client.font.reset")

rex.bind("cmd+1", "client.tab.goto", { index = 1 })
rex.bind("cmd+2", "client.tab.goto", { index = 2 })
rex.bind("cmd+3", "client.tab.goto", { index = 3 })
rex.bind("cmd+4", "client.tab.goto", { index = 4 })
rex.bind("cmd+5", "client.tab.goto", { index = 5 })
rex.bind("cmd+6", "client.tab.goto", { index = 6 })
rex.bind("cmd+7", "client.tab.goto", { index = 7 })
rex.bind("cmd+8", "client.tab.goto", { index = 8 })
rex.bind("cmd+9", "client.tab.goto", { index = -1 })

-- Load optional machine-specific settings last. Report errors in the file.
local ok, err = pcall(require, "local")
if not ok and not tostring(err):match("module '?local'? not found:") then
    error(err)
end
