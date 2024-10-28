local myrand = require "myrand"

local _this = {}

function _this:AlgKillFish(BulletTimes , FishTimes ) --bool {

	return myrand.Intn(0, FishTimes*BulletTimes) < BulletTimes
end

return _this
