local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "log"
local const = require "const"
local player = require "player"
local NetUtils = require "NetUtils"


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


function _this:SetBullet(req, ctx ) 
end

function _this:Fire(req, ctx ) 
	local pid = ctx.pid
	local fd = ctx.fd

	local deskId =  self:GetPidDeskIdMap(pid)
	if deskId == nil then
		log.printdump("Fire : deskId == nil", pid)
		return
	end

	local desk = self:GetIdDeskMap(deskId)
	if desk == nil then
		log.printdump("Fire : desk == nil", pid)
		return
	end

	skynet.send(desk, "lua", "Fire", ctx.pid,req) 
end

function _this:CollideFish(req, ctx ) 
end

function _this:LoginGame(req, ctx ) 
	local pid = ctx.pid
	local fd = ctx.fd

	local deskId = req.deskId
	local desk = self:GetIdDeskMap(deskId)
	if desk == nil then
		desk = skynet.newservice("desk")
		skynet.call(desk, "lua", "init", deskId)

		self:SetIdDeskMap(deskId, desk) 
	end
	local player_info = {
		PlayerId = pid,
		Con = fd,
	}
	local result = skynet.call(desk, "lua", "AddPlayer", player_info)
	if result == const.Ret.Ok then
		self:SetPidDeskIdMap(pid, deskId)
	end
	-- NetUtils:sendPackage(ctx.fd, req._response({ret=result}))
	return result
end

skynet.start(function()
	NetUtils:register()

    skynet.dispatch("lua", function(_,_, command, ...)
		local f = _this[command]
		if f then
			skynet.ret(skynet.pack(f(_this, ...)))
		else
			log.printdump("playermgr Unknown command : ", command)
			skynet.response()(false)
		end
	end)

    skynet.register "gamemgr"
end)