local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "log"
local myrand = require "myrand"
local mytime = require "mytime"

-- type SessionInf struct {
-- 	session   string
-- 	beginTime int
-- }

local IdToSession = {}
local SessionToId = {}

local CMD = {}

local tab = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ~!@#$%^&*()"
function MakeSession() --string {
	local l = #tab
    local buf = {}
	for i = 1, 16 do
		local index = myrand.Intn(1,l+1)
		buf[i] = tab:sub(index,index)
    end
	return table.concat(buf)
end

function  CMD.AddSession(pid ) --string {
	local session = MakeSession()
	local t = mytime.GetTime()
	IdToSession[pid] = {session = session, beginTime = t}
	SessionToId[session] = pid
	return session
end

function  CMD.GetSession(pid ) --string {
	local sessionInf = IdToSession[pid]
	if sessionInf == nil then
		return ""
    end
	return sessionInf.session
end

function  CMD.GetPid(session ) --int {
	local pid = SessionToId[session]
	if not pid  then
		return 0
    end
	return pid
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log("sessionmgr Unknown command : [%s]", command)
			skynet.response()(false)
		end
	end)

    skynet.register "sessionmgr"
end)