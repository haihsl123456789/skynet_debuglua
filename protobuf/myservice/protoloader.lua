

local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
local log = require "log"

local loader = {}
local data = {}

local function load(name)
	local filename = string.format("myproto/%s.sproto", name)
	local f = assert(io.open(filename), "Can't open " .. filename)
	local t = f:read "a"
	f:close()
	return sprotoparser.parse(t)
end

function loader.load(list)
	for i, name in ipairs(list) do
		local p = load(name)
		log("load proto [%s] in slot %d", name, i)
		data[name] = i
		sprotoloader.save(p, i)
	end
end

function loader.index(name)
	return data[name]
end

skynet.start(function()
	skynet.dispatch("lua", function (_,_, cmd, ...)
			local f = loader[cmd]
			if f then
				skynet.ret(skynet.pack(f(...)))
			else
				log("protoloader Unknown command : [%s]", cmd)
				skynet.response()(false)
			end
		end)
end)

