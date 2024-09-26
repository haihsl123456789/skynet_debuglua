local lfs = require("lfs")
local string = string

local bullet = require "bullet"
local log = require "log"
local cfgjson = require "cfgjson"



local _this = {}




function _this.test_file()
    -- 获取当前目录
    local current_dir = lfs.currentdir()
    -- 遍历目录
    for file in lfs.dir(current_dir) do
        -- 忽略当前目录和父目录
        if file ~= "." and file ~= ".." then
            local full_path = current_dir .. "/" .. file
            local attr = lfs.attributes(full_path)

            if attr.mode == "directory" then
                log.normal("Directory: " .. file)
            elseif attr.mode == "file" then
                log.normal("File: " .. file)
            end
        end
    end
end

function _this.test_bullet()
    local b = bullet.NewBullet(1, 100, 123, { X = 1, Y = 2 }, 555, 6)
    local ret = { hellox = "123" }
    b:GetSendData(ret)
    log.printdump(ret, "GetSendData: ")
end

function _this.string()
    local filename = "Title59.Json"  
    filename = string.lower(filename)
    
    -- 使用模式匹配解析字符串  
    local title, number, extension = string.match(filename, "^(%a+)(%d+)%.(%a+)$")  
    
    log.Println("Title:", title)       -- 输出: Title: title  
    log.Println("Number:", number)     -- 输出: Number: 59  
    log.Println("Extension:", extension) -- 输出: Extension: json  
end

function _this.cfgjson()
    cfgjson.Initcfgjson()
end

function _this.test()
    log.normal("--------------- test ====================")
    -- _this.test_bullet()
    -- _this.test_file()
    -- parseDir("./jsondata")
    -- _this.string()
    _this.cfgjson()
    log.normal("--------------- end test ====================################")
end

return _this
