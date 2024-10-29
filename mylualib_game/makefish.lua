local log = require "log"
local config = require "cfgjson"
local math = math
local mytime = require "mytime"
local myrand = require "myrand"
local utils = require "Utils"

local mfish = require "fish"

local _this = {}
local _M = {}

-- type MakeComponent struct {
-- 	owner Enity

-- 	freeIds    []int
-- 	curFreeId  int
-- 	freeOffset int
-- 	// tideIds []int
-- 	// curTideId int
-- 	// tideOffset int
-- 	// beginTime  int
-- 	baseTime   int //基准时间
-- 	timelength int //时长
-- 	// isMakeFree bool
-- }

function _this.NewMakeComponect(en ) --Component {
	local ret = {
            owner = en, 

            freeIds    = {}, --[]int
            curFreeId  = 0 ,
            freeOffset = 0 ,
            baseTime   = 0 , --基准时间
            timelength = 0 , --时长        
    }
	setmetatable(ret, {__index=_M})
	-- ret.owner = en
	-- ret.freeIds = make([]int, 0)
	return ret
end

function _M:Owner() --Enity {
	return self.owner
end

function _M:OwnerDesk() --*Desk {
	return self.owner --.(*Desk)
end

function _M:Init(freeFishIds , tideFishIds ) --{
	self.freeIds = utils:clone(freeFishIds)
end

function _M:BeginFree(t ) --{
	self.curFreeId = self.freeIds[math.random(1, #self.freeIds)]
	self.baseTime = t
	self.freeOffset = 0
	local cfg = config.GetFree(self.curFreeId)
	self.timelength = cfg.Time
end

function _M:MakeFish(curTime ) --(bool, []*Fish) {
	local t = curTime - self.baseTime
	local freecfg = config.GetFree(self.curFreeId)
	local cfgs = freecfg.Frees
	local fishs = {} --make([]*Fish, 0)
	if t >= self.timelength then
		return true, fishs
    end
	while self.freeOffset < #cfgs do
		local cfg = cfgs[self.freeOffset]
		if t < cfg.BeginTime then
			break
        end
		self.freeOffset = self.freeOffset + 1

		local tfishs = self:newFreeFish(cfg, self.baseTime+cfg.BeginTime)
        for k, v in ipairs(tfishs) do
            table.insert(fishs,  v)
        end
		-- fishs = append(fishs, tfishs...)
	end
	return false, fishs
end

local function getrandx(x ) --[]int) int {
	if #x == 1 then
		return x[0]
    elseif #x == 2 then
		return myrand.Intn(x[0], x[1]+1)
	end
	assert(false, "getrandx")
	return 0
end

function _M:newFreeFish(cfg --[[*config.SFreeConfig]], beginTime ) -- []*Fish {
	local fishs = {} --make([]*Fish, 0, 10)
	local makecnt = myrand.Intn(cfg.MakeCntMin, cfg.MakeCntMax+1)
    for i = 1, makecnt do
		local fish = mfish.NewFish(self:OwnerDesk().MakeFishId(), config.GetFishMapping(cfg.FishTypeId), beginTime+cfg.IntervalTime*i)
		local pos = {} --Point
		pos.X = (getrandx(cfg.XOffsets))+0.0  -- to float
		pos.Y = (getrandx(cfg.YOffsets))+0.0  -- to float
		fish:SetTrack(cfg.TrackIds[myrand.Intn(0, #cfg.TrackIds)], pos)
        table.insert(fishs, fish)
    end
	return fishs
end


return _this