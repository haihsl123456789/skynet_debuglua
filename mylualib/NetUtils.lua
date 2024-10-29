
local skynet = require "skynet"
-- local netpack = require "netpack"
local sprotoloader = require "sprotoloader"
local socket = require "skynet.socket"
local string = require "string"
local log = require "log"

local this={
    host=nil,
    send_request=nil
}
    
local function send_package(fd,pack)
    if fd then
        if type(fd) == "number" then
	        local package = string.pack(">s2", pack)

	        socket.write(fd, package)
        end
    end
end
    
                
function this:pushMessage(fd,proto_name,message)
--print("pushMessage:",proto_name)
        send_package( fd, self.send_request( proto_name, message  ) )   
end
  
function this:register( proto_file )
    self.host = sprotoloader.load(1):host "package"
	self.send_request = self.host:attach(sprotoloader.load(2))

    -- proto_file = proto_file or "sv_game_proto"
	-- local protoloader = skynet.uniqueservice "protoloader"
	-- local slot = skynet.call(protoloader, "lua", "index", proto_file..".c2s" ) 
	-- self.host = sprotoloader.load(slot):host "package"
	-- local slot2 = skynet.call(protoloader, "lua", "index", proto_file..".s2c" )
	-- self.send_request = self.host:attach(sprotoloader.load(slot2))
end

function this:packRequest(proto_name, message)
--	log.debug("nt: %s,%s",proto_name,debugEx:dump(message))
	return self.send_request( proto_name, message  )  
end
    
function this:sendPackage(fd,pack )
--	log.debug("send: %s",debugEx:dump(message))
	send_package( fd, pack )   
end
    

    
function this:getHost()
    return self.host
end

function this:getPackRequest()
    return self.send_request
end




return this
