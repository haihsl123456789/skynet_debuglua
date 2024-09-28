local skynet = require "skynet"
require "skynet.manager"

local _this = {}

-- milli second  todo: now is time from begin server, but change to timestamp
function _this.GetTime() 
	return skynet.now()*10
end



return _this