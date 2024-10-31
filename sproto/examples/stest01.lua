local skynet = require "skynet"


local function main_loop()
	skynet.fork(function()
		local i = 0
		while true do
			skynet.sleep(100)
			i = i + 1
			skynet.error("loop", i)
		end
	end
	)
end

skynet.start(function()
	skynet.fork(main_loop)
end)
