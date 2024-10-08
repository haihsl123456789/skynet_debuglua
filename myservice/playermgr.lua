local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "log"


local _this = {
    IdDeskMap    = {},
	PidDeskIdMap = {},
	ConPipMap    = {},
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

function _this:GetConPipMap(con ) --(int, bool) 
	return self.ConPipMap[con]
end

function _this:SetConPipMap(con , pid ) 
	self.ConPipMap[con] = pid
end

function _this:DelConPipMap(con ) 
    self.ConPipMap[con] = nil
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