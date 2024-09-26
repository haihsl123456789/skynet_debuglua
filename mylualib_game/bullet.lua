
local _this = {}
local _M = {}

function  _this.NewBullet(id, bulletTimes, targetFishId , direction , makeTime , lifeTime )
    local ret = {
        BulletId = id,
        BulletType = 1,
        BulletTimes = bulletTimes,
        TargetFishId = targetFishId,
        Direction = direction,
        MakeTime = makeTime,
        EndLifeTime = makeTime + lifeTime
    }
    setmetatable(ret, {__index = _M})
    return ret
end

function _M:SetOwerInfo(pid , playerpostion ) 
	self.OwerId = pid
	self.OwerPosition = playerpostion
end

function _M:GetSendData(data ) --*protodata.Bullet) 
	data.TimeStamp = (self.MakeTime)
	data.BulletId = (self.BulletId)
	data.Direction = {X=(self.Direction.X), Y= (self.Direction.Y)}
	data.BulletTimes = (self.BulletTimes)
	data.TargetFishId = (self.TargetFishId)
	data.BulletType = (self.BulletType)
	data.Position = (self.OwerPosition)
end

function _M:IsOutTime(t )  
	return t >= self.EndLifeTime
end

function _M.Update(curTime ) 
end

return _this


