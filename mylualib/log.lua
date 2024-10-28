local skynet = require "skynet"
local os = require "os"
local log = {}

function log.debug(fmt, ...)
--	print(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end



function log.console(fmt, ...)
	print(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.normal(fmt, ...)
	skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.warning(fmt, ...)
	skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

--[[
function log.error(fmt, ...)
    skynet.error("for trace:"..fmt)
	skynet.error(os.date("%Y.%m.%d_%X " ).."error: "..string.format(fmt, ...))
end
]]



function log.database(fmt, ...)
	skynet.error(os.date("%Y.%m.%d_%X " ).."db_log:"..string.format(fmt, ...))
end


function log.format(fmt, ...)
	skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.error(fmt,...)
    

	local currentFile=os.date("%Y_%m_%d")..".error"
	if currentFile ~=log._fileerror then
		log._fileerror=currentFile
        if log._fileerrorIO then log._fileerrorIO:close() end
		log._fileerrorIO=io.open(currentFile,"a")
	end
	
	log._fileerrorIO:write(string.format(os.date("%H:%M:%S ")..fmt.."\r\n",...))
    log._fileerrorIO:flush()

     skynet.error(os.date("%Y.%m.%d_%X " ).."error: "..string.format(fmt, ...))
end

function log.log(fmt,...)
	local currentFile=os.date("%Y_%m_%d")..".log"
	if currentFile ~=log._filelog then
		log._filelog=currentFile
        if log._filelogIO then log._filelogIO:close() end
		log._filelogIO=io.open(currentFile,"a")
	end
	
	log._filelogIO:write(string.format(os.date("%H:%M:%S ")..fmt.."\r\n",...))
    log._filelogIO:flush()

    print(string.format(os.date("%H:%M:%S ")..fmt.."\r\n",...))
end


--[[
dump∂‘œÛ
@param mixed obj
@return string
]]
function log.dump(obj)
    local getIndent, quoteStr, wrapKey, wrapVal, isArray, dumpObj
    getIndent = function(level)
        return string.rep("\t", level)
    end
    quoteStr = function(str)
        str = string.gsub(str, "[%c\\\"]", {
            ["\t"] = "\\t",
            ["\r"] = "\\r",
            ["\n"] = "\\n",
            ["\""] = "\\\"",
            ["\\"] = "\\\\",
        })
        return '"' .. str .. '"'
    end
    wrapKey = function(val)
        if type(val) == "number" then
            return "[" .. val .. "]"
        elseif type(val) == "string" then
            return "[" .. quoteStr(val) .. "]"
        else
            return "[" .. tostring(val) .. "]"
        end
    end
    wrapVal = function(val, level)
        if type(val) == "table" then
            return dumpObj(val, level)
        elseif type(val) == "number" then
            return val
        elseif type(val) == "string" then
            return quoteStr(val)
        else
            return tostring(val)
        end
    end
    local isArray = function(arr)
        local count = 0 
        for k, v in pairs(arr) do
            count = count + 1 
        end 
        for i = 1, count do
            if arr[i] == nil then
                return false
            end 
        end 
        return true, count
    end
    dumpObj = function(obj, level)
        if type(obj) ~= "table" then
            return wrapVal(obj)
        end
        level = level + 1
        local tokens = {}
        tokens[#tokens + 1] = "{"
        local ret, count = isArray(obj)
        if ret then
            for i = 1, count do
                tokens[#tokens + 1] = getIndent(level) .. wrapVal(obj[i], level) .. ","
            end
        else
            for k, v in pairs(obj) do
                tokens[#tokens + 1] = getIndent(level) .. wrapKey(k) .. " = " .. wrapVal(v, level) .. ","
            end
        end
        tokens[#tokens + 1] = getIndent(level - 1) .. "}"
        return table.concat(tokens, "\n")
    end
    return dumpObj(obj, 0)
end

--[[
function log.debug(fmt, ...)
	--print(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.console(fmt, ...)
	--print(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.normal(fmt, ...)
	--skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.warning(fmt, ...)
	--skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end

function log.error(fmt, ...)
    --skynet.error("for trace:"..fmt)
	--skynet.error(os.date("%Y.%m.%d_%X " ).."error: "..string.format(fmt, ...))
end

function log.database(fmt, ...)
	skynet.error(os.date("%Y.%m.%d_%X " ).."db_log:"..string.format(fmt, ...))
end


function log.format(fmt, ...)
	--skynet.error(os.date("%Y.%m.%d_%X " )..string.format(fmt, ...))
end
]]
function log.__call(self, ...)
	if select("#", ...) == 1 then
		skynet.error(tostring((...)))
	else
		self.format(...)
	end
end



-- function log.printdump(obj,str )
--     if str then
--         log.normal(str)
--     end
--     log.normal( log.dump(obj) )
-- end

local tostring = require "tostring"
function log.printdump(...)
	local s = ""
    for _, v in ipairs({...}) do
        s = s .. tostring(v)
    end
	print(s)
end

function log.Println(...)
    skynet.error(os.date("%Y.%m.%d_%X " ), ...)
end

function log.Fatalln(...)
    skynet.error(os.date("%Y.%m.%d_%X " ), ...)
    assert(false, "log.Fatalln")
end


return setmetatable(log, log)
