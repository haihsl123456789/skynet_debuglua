package.cpath = "luaclib/?.so"
package.path = "lualib/?.lua;examples/?.lua;myclient/?.lua"

if _VERSION ~= "Lua 5.4" then
	error "Use lua 5.4"
end

local log = require "log"
local socket = require "client.socket"
-- local proto = require "proto"
-- local sproto = require "sproto"

------
-- local skynet = require "skynet"
local sprotoparser = require "sprotoparser"
local sprotoloader = require "sprotoloader"
-- local log = require "log"

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
		-- log("load proto [%s] in slot %d", name, i)
		data[name] = i
		sprotoloader.save(p, i)
	end
end

function loader.index(name)
	return data[name]
end

loader.load( {
	"game.c2s",
	"game.s2c",
})

----

local host = sprotoloader.load(2):host "package"
local request = host:attach(sprotoloader.load(1))

-- local host = sproto.new(proto.s2c):host("package")
-- local request = host:attach(sproto.new(proto.c2s))


local fd = assert(socket.connect("127.0.0.1", 5000))

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local saveReqs = {}

local function send_request(name, args)
	session = session + 1
	
	saveReqs[session] = {name=name,args=args}

	local str = request(name, args, session)
	send_package(fd, str)
	print("Request:", session, name, log.dump(args))
end

local last = ""

local function print_request(name, args)
	print("REQUEST", name, log.dump(args))
end

local function print_response(session, args, name)
	print("RESPONSE--", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		local name, args = ...
		print_request(name, args)
	else
		local session, args = ...
		assert(t == "RESPONSE")

		local name =  saveReqs[session] and saveReqs[session].name

		print_response(session, args, name)

		if name == "Login" then
			if args.result == 0 then
				send_request("LoginGame", {token=args.token,deskId=112 })		
			end
		elseif name == "LoginGame" then			
			if args.ret == 0 then
				send_request("Fire", {bulletType=1, bulletTimes=2,direction={x=1,y=2}, targetFishId=0})		
			end
		end

		saveReqs[session] = nil
	end
end

local function dispatch_package()
	while true do
		local v
		v, last = recv_package(last)
		if not v then
			break
		end

		print_package(host:dispatch(v))
	end
end

send_request("handshake")
send_request("set", { what = "hello", value = "world" })
while true do
	dispatch_package()
	local cmd = socket.readstdin()
	if cmd then
		if cmd == "quit" then
			send_request("quit")
		elseif cmd == "login" then
			send_request("Login", {username="jack", password="123456"})			
		else
			send_request("get", { what = cmd })
		end
	else
		socket.usleep(100)
	end
end
