local skynet = require "skynet"
local socket = require "skynet.socket"
local sproto = require "sproto"
local sprotoloader = require "sprotoloader"
local log = require "log"
local const = require "const"
local db = require "db"
local dbpool = require "dbpool"
local config = require "config"
local NetUtils = require "NetUtils"
local mydbpool

local WATCHDOG
local host
local send_request

local CMD = {}
local REQUEST = {}

local ctx = {pid = 0, fd = 0}

function REQUEST:get()
	print("get", self.what)
	local r =   "world" -- skynet.call("SIMPLEDB", "lua", "get", self.what)
	return { result = r }
end

function REQUEST:set()
	print("set", self.what, self.value)
	-- local r = skynet.call("SIMPLEDB", "lua", "set", self.what, self.value)
end

function REQUEST:handshake()
	return { msg = "Welcome to skynet, I will send heartbeat every 5 sec." }
end

function REQUEST:Login()
	print("Login", self.username, self.password)

    --todo check username password
	local dbcon = mydbpool:getCon()
	if db:checkAccount(dbcon, self.username, self.password) == false then
		mydbpool:putCon(dbcon)

		return { result = const.Ret.SessionError}
	end
	mydbpool:putCon(dbcon)
    --

    local pid = 123
    ctx.pid = pid
    local session = skynet.call("sessionmgr", "lua", "AddSession", pid)
	
    return { result = 0, pid = pid, token = session }
end

function REQUEST:LoginGame()
	log.printdump(self, "LoginGame")

	local pid = skynet.call("sessionmgr", "lua", "GetPid", self.token)
	if pid ==0 then
		return {ret=const.Ret.SessionError}	 --session error
	end

	local ret = skynet.call("gamemgr", "lua", "LoginGame", self,  ctx )
	return { ret = ret}
end

function REQUEST:SetBullet()
	log.printdump(self, "SetBullet")
	local ret = skynet.send("gamemgr", "lua", "SetBullet",  self, ctx)
	-- return { ret = 0}
end

function REQUEST:Fire()
	log.printdump(self, "Fire")
	-- return { ret = 0}
end

function REQUEST:CollideFish()
	log.printdump(self, "CollideFish")
	local ret = skynet.send("gamemgr", "lua", "CollideFish",  self, ctx)
	-- return { ret = 0}
end

function REQUEST:quit()
	skynet.call(WATCHDOG, "lua", "close", ctx.fd)
end

local function request(name, args, response)
	args = args or {}
	-- args._response = response

	local f = assert(REQUEST[name])
	local r = f( args, response)
	if response then
		return response(r)
	end
end

local function send_package(pack)
	local package = string.pack(">s2", pack)
	socket.write(ctx.fd, package)
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = function (msg, sz)
		return host:dispatch(msg, sz)
	end,
	dispatch = function (fd, _, type, ...)
		assert(fd == ctx.fd)	-- You can use fd to reply message
		skynet.ignoreret()	-- session is fd, don't call skynet.ret
		skynet.trace()
		if type == "REQUEST" then
			local ok, result  = pcall(request, ...)
			if ok then
				if result then
					send_package(result)
				end
			else
				skynet.error(result)
			end
		else
			assert(type == "RESPONSE")
			error "This example doesn't support request client"
		end
	end
}

function CMD.start(conf)

	mydbpool = dbpool.NewPool(config.db, 10)

	local fd = conf.client
	local gate = conf.gate
	WATCHDOG = conf.watchdog
	-- slot 1,2 set at main.lua
	host = sprotoloader.load(1):host "package"
	send_request = host:attach(sprotoloader.load(2))
	skynet.fork(function()
		while true do
			send_package(send_request "heartbeat")
			skynet.sleep(500)
		end
	end)

	ctx.fd = fd
	skynet.call(gate, "lua", "forward", fd)
end

function CMD.disconnect()
	-- todo: do something before exit
	skynet.exit()
end

skynet.start(function()
	NetUtils:register()

	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.trace()
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
