local skynet = require "skynet"
local sprotoloader = require "sprotoloader"

local max_client = 64

skynet.start(function()
	skynet.error("stest01 Server start")

	skynet.newservice("stest_called")
	-- local ret = skynet.call("called","lua","set","hello", "world" )
	local ret = skynet.send("called","lua","set","hello", "world" )
	skynet.error("ret: ", ret)

	skynet.newservice("stest_call")

	skynet.exit()
end)
