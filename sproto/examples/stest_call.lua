local skynet = require "skynet"
require "skynet.manager"

local function main_loop()
	local i = 0
	while true do
		skynet.sleep(100)
		i = i + 1
		local ret,result = skynet.call("called","lua","get","hello" )
		skynet.error("loop", i,  ret, result)
	end
end



skynet.start(function()
	skynet.fork(main_loop)

	skynet.register("call")
end)
