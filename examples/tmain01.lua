local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 64

skynet.start(function()
	skynet.error("stest01 Server start")


	skynet.newservice("stest01")


	skynet.exit()
end)
