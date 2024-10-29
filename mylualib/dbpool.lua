local skynet = require "skynet"
require "skynet.manager" -- import skynet.register
local log = require "log"

local mysql = require "skynet.db.mysql"
local C_MAX_MYSQL_CONNECT = 10

local function newConnect(dbconfig)
    local db = mysql.connect({
        host = dbconfig.host,
        port = dbconfig.port,
        database = dbconfig.database,
        user = dbconfig.user,
        password = dbconfig.password,
        max_packet_size = 10 * 1024 * 1024,
        --		on_connect = on_connect
    })

    if not db then
        log.printdump("failed to connect", dbconfig)
        return nil
    end
    local str = "set charset utf8"
    local res = db:query(str)
    if not res or res.errno then
        log.printdump("sql error sql,ret,", dbconfig, str, res)
        db = nil
        return nil
    end

    return { database = db, isQuerying = false }
end

local _M = {}
function _M:init(dbconfig, max_con)
    self.dbconfig = dbconfig
    self.cfg_max_con = max_con
    self.connect = {}

    max_con = max_con or C_MAX_MYSQL_CONNECT
    local cnt = 0
    while cnt < max_con do
        local r = newConnect(dbconfig)
        if r then
            cnt = cnt + 1
            self.connect[cnt] = r
        else
            log.error("%s:initConnect error, rel cnt:%s", dbconfig.database, cnt)
            break
        end
    end
    self.max_con = cnt
    log.debug("sql connect:%d", self.max_con)

    return self.max_con > 0
end

function _M:release()
    for cnt = 1, self.max_con do
        if self.connect[cnt] then
            self.connect[cnt].database:disconnect()
            self.connect[cnt] = nil
        end
    end
    self.max_con  = 0
    self.connect = {}
end

function _M:getCon()
    while self.max_con > 0 do
        for cnt = 1, self.max_con do
            if not self.connect[cnt].isQuerying then
                self.connect[cnt].isQuerying = true
                --print("===cnt:",cnt)
                --print("dc --[+]--player connect")
                return self.connect[cnt].database
            end
        end
        log.error("%s: getConnent:no connect", self.dbconfig.database, self.max_con)
        skynet.sleep(10)
    end
    return nil    
end

function _M:putCon(con)
    con.isQuerying = false
end

local _this = {}
--[[
dbconfig:
        host 
        port
        database 
        user 
        password 
        max_packet_size = 
]]
function _this.NewPool(dbconfig, max_con)
    local ret = setmetatable({}, { __index = _M })
    ret:init(dbconfig, max_con)

    return ret
end

return _this


