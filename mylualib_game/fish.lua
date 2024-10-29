local log = require "log"
local config = require "cfgjson"
local math = math

local _this = {}
local _M = {}

-- type Point struct {
-- 	X float64
-- 	Y float64
-- }

-- type Fish struct {
-- 	FishId     int
-- 	FishTypeId int

-- 	TrackId      int
-- 	TrackOffsest Point
-- 	-- FishPostion  Point
-- 	FishTimes int

-- 	MakeTime    int
-- 	LifeTime    int
-- 	EndLifeTime int

-- 	Config *config.SFishConfig
-- }
function _this.NewPoint(x, y) 
    return {
        X = x or 0,
        Y = y or 0
    }
end

function _this.NewFish(id , fishtypeid , maketime ) 
	local ret = {
        	FishId  = 0 ,
            FishTypeId = 0 ,

            TrackId    = 0 ,
            TrackOffsest = _this.NewPoint(),
            -- FishPostion  Point
            FishTimes = 0 ,

            MakeTime    = 0 ,
            LifeTime    = 0 ,
            EndLifeTime = 0 ,
            -- Config = 
    }
	ret.FishId = id
	ret.FishTypeId = fishtypeid

	ret.Config = config.GetFish().FishMap[fishtypeid]
	if ret.Config ~= nil then
		log.Println("NewFish: fishtypeid:", fishtypeid)
    end
	-- self.FishPostion =
	ret.FishTimes = math.random(ret.Config.TimesMin, ret.Config.TimesMax)
	ret.MakeTime = maketime
    setmetatable(ret, {__index = _M})
	return ret
end

function _M:SetTrack(trackId , trackOffset ) 
	self.TrackId = trackId
	self.TrackOffsest = trackOffset

	self.LifeTime = config.GetTrackTime(trackId)
	self.EndLifeTime = self.MakeTime + self.LifeTime
end

function _M:GetSendData(data ) 
	data.TimeStamp = (self.MakeTime)
	data.FishId = (self.FishId)
	data.FishTypeId = (self.FishTypeId)
	data.TrackId = (self.TrackId)
	data.TrackOffset = self.TrackOffsest
end

function _M:IsInLifeTime(t ) 
	return (t >= self.MakeTime and t < self.EndLifeTime)
end

function _M:IsOutTime(t ) 
	return (t >= self.EndLifeTime)
end

function _M:ChangeEndLifeTime(endLifeTime ) 
	if self.EndLifeTime > endLifeTime then
		self.EndLifeTime = endLifeTime
		self.LifeTime = self.EndLifeTime - self.MakeTime
    end
end

function _M:Update(curTime ) 
	if not self.IsInLifeTime(curTime) then
		return
    end
	--todo: update position
end


return _this
