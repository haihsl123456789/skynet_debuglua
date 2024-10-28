local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "log"
local const = require "const"


local _this = {
    IdDeskMap    = {},
	PidDeskIdMap = {},
}

function _this:GetIdDeskMap(id ) --(*Desk, bool) 
	local desk = self.IdDeskMap[id]
	return desk
end

function _this:SetIdDeskMap(id , desk ) 
	self.IdDeskMap[id] = desk
end

function _this:DelIdDeskMap(id ) 
    self.IdDeskMap[id] = nil
end

function _this:GetPidDeskIdMap(id ) --(int, bool) 
	return  self.PidDeskIdMap[id]
end

function _this:SetPidDeskIdMap(id , desk) 
	self.PidDeskIdMap[id] = desk
end

function _this:DelPidDeskIdMap(id ) 
    self.PidDeskIdMap[id] = nil
end


------------------------------------









------------------------------------
function _this:LoginGame(req, ctx ) 
	local pid = ctx.pid
	local fd = ctx.fd

	local deskId = self:GetPidDeskIdMap(ctx.pid)
	if deskId == nil then
		local desk = skynet.newservice("desk")
		deskId = skynet.call(desk, "lua", "GetDeskId")

		self:SetIdDeskMap(deskId, desk) 
	end
	local desk = self:GetIdDeskMap(deskId)
	local result = skynet.call(desk, "lua", "AddPlayer", pid, fd)
	if result == const.Ret.Ok then
		self:SetPidDeskIdMap(pid, deskId)
	end
	return result
end

skynet.start(function()

    skynet.dispatch("lua", function(_,_, command, ...)
		local f = _this[command]
		if f then
			skynet.ret(skynet.pack(f(_this, ...)))
		else
			log("playermgr Unknown command : [%s]", command)
			skynet.response()(false)
		end
	end)

    skynet.register "playermgr"
end)