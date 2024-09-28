local log = require "log"
local config = require "cfgjson"
local math = math
local mytime = require "mytime"

local _this = {}
local _M = {}

-- type PlayerBase struct {
-- 	PlayerId int
-- 	Nickname string
-- 	Sex      int

-- 	Gold int
-- 	Con  *ws.Connect
-- }

-- type Player struct {
-- 	PlayerBase

-- 	IdBulletSet map[int]int
-- 	Position    int
-- 	SitDownTime int

-- 	savegold int
-- 	win      int
-- 	lose     int
-- }

function _this.NewPlayer(pid , con ) --*Player {
	local ret = {
        --base
        PlayerId = 0,
        Nickname = "",
        Sex      = 0,

        Gold = 0,
        Con  = nil, --*ws.Connect
        --    
        IdBulletSet = {}, --map[int]int
        Position    = 0,
        SitDownTime = 0,

        savegold = 0,
        win      = 0,
        lose     = 0,
    }
	ret.PlayerId = pid
	ret.Con = con

	ret.Gold = 1000000
	ret.IdBulletSet = {}

    setmetatable(ret, {__index = _M})
	ret:payoutreset()
	return ret
end

function _M:payoutreset() 
	self.win = 0
	self.lose = 0
	self.savegold = self.Gold
end

function _M:SetPosition(pos ) 
	self.Position = pos
end

function _M:SetSitDownTime() 
	self.SitDownTime = mytime.GetTime()
end

function _M:RemoveBullet(bulletid ) 
    self.IdBulletSet[bulletid] = nil
end

function _M:InsertBullet(bulletid ) 
	local v = self.IdBulletSet[bulletid]
	if v ~= nil  then
		log.Println("re InsertBullet", bulletid)
    end
	self.IdBulletSet[bulletid] = bulletid
end

function _M:EnoughGold(gold ) --bool 
	return self.Gold >= gold
end

function _M:AddGold(gold ) 
	self.Gold = self.Gold + gold
	self.win = self.win + gold
end

function _M:SubGold(gold ) 
	assert(self.Gold >= gold, "SubGold: self.Gold >= gold")
	self.Gold = self.Gold - gold
	self.lose = self.lose + gold
end

function _M:Payout() --(int, int, int) 
	local win, lose, fee = self.win, self.lose, 0
	self:payoutreset()
	return win, lose, fee
end

function _M:Update(curTime ) 
end

function _M:SendMsg(pMsg ) --interface{}) 
	self.Con.Send(pMsg)
end


return _this