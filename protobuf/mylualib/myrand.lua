

local _this = {}

--[minv, maxv)
function _this.Intn(minv , maxv ) --int {
	assert(maxv > minv)
	return math.random(minv, maxv-1)
end


return _this