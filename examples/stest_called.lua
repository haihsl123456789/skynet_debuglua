local skynet = require "skynet"
require "skynet.manager"
local os = require "os"


local CMD = {}
local cache = {}
CMD.sum = function(a, b)
	return a + b
end
CMD.set = function(key, value)
	cache[key] = value
end
CMD.get = function(key)
	return cache[key] 
end

local function log(fmt, ...)
	skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log("called unknown command : [%s]", command)
			skynet.response()(false)
		end
	end)

    skynet.register("called")
end)
