local skynet = require "skynet"
local config = require "config"
local mysql = require "skynet.db.mysql"
local log = require "log"
local const=require "const"
local debugEx=require "debugEx"

local test = require "test"  
    
skynet.start(function()
	skynet.error("Server start")

	test.test()
	
	local proto=skynet.uniqueservice("protoloader")
	skynet.call(proto, "lua", "load", {
		"game.c2s",
		"game.s2c",
	})
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console", 8001)

	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 5000,      
		maxclient = 64,
		nodelay = true,	
	})
	skynet.error("Watchdog listen on", 5000)

	skynet.exit()
end)


