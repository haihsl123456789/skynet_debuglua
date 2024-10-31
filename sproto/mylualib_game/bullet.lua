
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
	data.timeStamp = (self.MakeTime)
	data.bulletId = (self.BulletId)
	data.direction = {X=(self.Direction.X), Y= (self.Direction.Y)}
	data.bulletTimes = (self.BulletTimes)
	data.targetFishId = (self.TargetFishId)
	data.bulletType = (self.BulletType)
	data.position = (self.OwerPosition)
end

function _M:IsOutTime(t )  
	return t >= self.EndLifeTime
end

function _M.Update(curTime ) 
end

return _this


