local skynet = require "skynet"
require "skynet.manager" -- import skynet.register
local log = require "log"

local mysql = require "mysql"

local _this={}

function _this:checkAccount(db, un, pw)
    local query = string.format([[select * from account where username = %s and password=password(%s)]], un, pw) 
    print("query: ",query)
    local res = db:query(query)
    if res.errno ~= nil then
        return false, "db error"
    end
    return #res ~=0, nil
end


return _this