    
local this={
}
       
function this:getrelnTab(tab)
	local n=0
	for _,v in pairs(tab) do
		n=n+1
	end
	return n
end

function this:combineITab(dest_tab,src_tab )
    for _,value in ipairs(src_tab) do
        table.insert(dest_tab,value)
    end
end
    
function this:combineITabEx(dest_tab,src_tab,from, to  )
    if from and to then
        for idx=from,to do
            table.insert(dest_tab,src_tab[idx])
        end
    else
        for _,value in ipairs(src_tab) do
            table.insert(dest_tab,value)
        end
    end
end

function this:combineTab(dest_tab,src_tab )
    for key,value in pairs(src_tab) do
        dest_tab[key] = value
    end
end

function this:clone(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for key, value in pairs(object) do
            new_table[_copy(key)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end

function this:confusionTable( tab, para_count )
    local cnt = #tab
    for i = 1, cnt*para_count do
        local temp = table.remove(tab, math.random(1,cnt ) )
        table.insert(tab,temp)
    end
end
    
function this:ifThenElse(_if,_then,_else)
    if _if then return _then else return _else end
end
--tab = {[1]=number1,[2]=number2,...}
function this:removeNumberFromITab(tab,number)
    local ret = false
    for key, value in ipairs( tab ) do
        if value==number then
            table.remove(tab,key)
            break
        end
    end
    return ret
end
--不能嵌套,lock不成就失败返回    
function this:lock( lock_tab,  lock_id )
    if lock_tab[lock_id] then
        return false
    end

    lock_tab[lock_id] = true
    return true
end
    
function this:unlock( lock_tab,  lock_id )
    lock_tab[lock_id] = false
end
    
----不能嵌套,lock不成死等
function this:lock2( lock_tab,  lock_id, sleep_time )
    local skynet = require "skynet"    

    sleep_time = sleep_time or 5 
    while lock_tab[lock_id] do
        skynet.sleep( sleep_time )
    end

    lock_tab[lock_id] = true
end
    
function this:unlock2( lock_tab,  lock_id )
    lock_tab[lock_id] = false
end
    

    
--[[
function this:sortITab( tab,sort_f)
    local max = #tab
    local t
    if max>1 then
        for i=1,max-1 do
            for j=i+1,max do
                if  sort_f(tab[j],tab[i]) then
                    t = tab[i]
                    tab[i]=tab[j]
                    tab[j]=t
                    debugEx:printdump(tab[i],"tab[i]:")
                end
            end
        end
    end
end
]]




return this
