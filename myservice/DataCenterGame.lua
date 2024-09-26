local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "log"
--local DatabaseMysql = require "DatabaseMysql"
local json = require "json"
local Utils=require "Utils"
local GM = Utils.GM

local debugEx = require "debugEx"
local mysql = require "mysql"
local ServerConfig = require "ServerConfig"
local connent={}
local C_MAX_MYSQL_CONNECT = 10 

local server_name ="DCGame"

--=========================================== 公共代码 =========================================================
local log_imp_err	--需要恢复的错误日志
local function log_imp(str)
	log_imp_err:write(os.date("%Y.%m.%d_%X ;")..str.."\r\n")
	log_imp_err:flush()
end
local function log_imp2(fm,...)
    log.database(fm,...)

    local str = string.format(fm,...)
    log_imp(str)
end
local function newConnect()
	local dbconfig = ServerConfig.dbGame
	local db=mysql.connect({		
		host=dbconfig.host,port=dbconfig.port,database=dbconfig.database,user=dbconfig.user,password=dbconfig.password,
		max_packet_size = 10*1024*1024,
--		on_connect = on_connect
	})

	if not db then
		log.error("%s:failed to connect",server_name)
		return nil	
	end	
	local str="set charset utf8"
	local res=db:query(str)
	if not res or res.errno then
		log.error("%s:sql error sql:%s,ret:%s",server_name,str,debugEx:dump( res ) )
		db = nil
		return nil
	end

	return {database=db,isQuerying=false}
end

local function initConnect(connect_cnt)
	local r
	local cnt=0
	local con_req = connect_cnt or C_MAX_MYSQL_CONNECT
    while cnt < con_req do
		r=newConnect()
		if r then
			cnt = cnt + 1
        	connent[cnt] = r
		else			
			log.error("%s:initConnect error, rel cnt:%s",server_name,cnt)
			break
		end
    end
	mysql_con_cnt_rel = cnt
	log.debug("sql connect:%d",mysql_con_cnt_rel)	

	log_imp_err=io.open(server_name.."_Err.log","a+")
	log_imp( "======================= start =======================" )
	if mysql_con_cnt_rel<1 then
		log_imp( "connect err!" )
	end
--	log_imp_err:close()
	return mysql_con_cnt_rel>0
end

local function exitConnect()
    for cnt=1,mysql_con_cnt_rel do
		if connent[cnt] then
        	connent[cnt].database:disconnect()
			connect[cnt]=nil
		end
    end
	mysql_con_cnt_rel = 0
	log_imp_err:close()
end

    
local function getConnent()
    while mysql_con_cnt_rel>0 do
        for cnt=1,mysql_con_cnt_rel do
            if not connent[cnt].isQuerying then
                connent[cnt].isQuerying = true
--print("===cnt:",cnt)
--print("dc --[+]--player connect")
                return  connent[cnt]
            end
        end  
        log.error("%s: getConnent:no connent",server_name,mysql_con_cnt_rel)
        skynet.sleep(10)
    end
    return nil 
end

local function freeConnect( con )
--	print("dc --[-]--player disconnect")
    con.isQuerying = false
end


--[[
功能：运行单行结果查询语句
参数：
	query：sql 语句
	cont：mysql链接，nil时内部获得
	holdfalg：true:不释放链接，否则释放
返回：
	第1返回值：结果，0正确，其他错误
	第2返回值：结果
	第3返回值：链接
]]
local function select_row_one_function(query,cont,hold_falg)
	local con
	if cont then
		con=cont
	else
		con = getConnent()
		if not con then
			log.error("%s: get connect err!",server_name)
			return 300, nil,nil
		end
	end
	
	local res = con.database:query(query) 
	log.debug("%s:sql debug sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
	if not hold_falg then
		freeConnect(con) 
		con=nil
	end

	if not res then
		log.error("%s: sql error res empty:%s",server_name,query )	
		return 303,nil,con
	end	
	
	if res.errno ~= nil then
		log.error("%s:sql error sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
		return res.errno	
	elseif next(res)==nil then
		return 0,{},con
	end	

	return 0,res[1],con
end


--[[
功能：运行多行结果查询语句
参数：
	query：sql 语句
	cont：mysql链接，nil时内部获得
	holdfalg：true:不释放链接，否则释放
返回：
	第1返回值：结果，0正确，其他错误
	第2返回值：结果
	第3返回值：链接
]]
local function select_rows_function(query,cont,hold_falg)
	local con
	if cont then
		con=cont
	else
		con = getConnent()
		if not con then
			log.error("%s: get connect err!",server_name)
			return 301,nil,nil
		end
	end
	local res = con.database:query(query) 
	log.debug("%s:sql debug sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
	if not hold_falg then
		freeConnect(con) 
		con=nil
	end

	if not res then
		log.error("%s: sql error res empty:%s",server_name,query )	
		return 303,nil,con
	end	
	
	if res.errno ~= nil then
		log.error("%s:sql error sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
		return res.errno,nil,con
	end
	return 0,res,con
end


--[[
功能：运行多行查询语句
参数：
	query：sql 语句
]]
local function select_mult_rows_function(query)
	local con = getConnent()
	if not con then
		log.error("%s: get connect err!",server_name)
		return 301
	end
	local db = con.database 
	if not db then
		freeConnect(con)
		log.error("%s: get db err!",server_name)
		return 302
	end
	local res = db:query(query) 
	log.debug("%s:sql debug sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
	freeConnect(con) 
	if not res then
		log.error("%s: sql error res empty:%s",server_name,query )	
		return 303
	end	
	
	if  not res.mulitresultset or res.mulitresultset ~= true then
		log.error("%s:sql error no mulitresultset sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
		return 304
	end
	
	if res.errno ~= nil then
		log.error("%s:sql error sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
		return res.errno	
	end
	return 0,res
end

--[[
功能：更新单行语句
注意：如果新值和旧值一样也认为失败
参数：
	query：sql 语句
	cont：mysql链接，nil时内部获得
	holdfalg：true:不释放链接，否则释放
	ignore_err:该错误无需记录，可以为nil
返回：
	第1返回值：结果，0正确，其他错误
	第2返回值：链接
	结果集：
]]
local function iud_row_one_function(query,cont,hold_falg,ignore_err)
	local con
	local err
	if cont then
		con=cont
	else
		con = getConnent()
		if not con then
			log.error("%s: get connect err!",server_name)
			return 300, nil,nil
		end
	end
	
	local res = con.database:query(query) 
	log.debug("%s:sql debug sql:%s,ret:%s",server_name,query,debugEx:dump( res ) )	
	if not hold_falg then
		freeConnect(con) 
		con=nil
	end

	if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then		
		err = res.errno or 1
		if err ~= ignore_err then
			log.error("sql error sql:%s,ret:%s",query,debugEx:dump( res ) )	
		end
	else
		err = 0
	end

	return err,con,res
end

--=========================================== 公共代码 =========================================================
local CMD={}

function CMD.readTotalStatistics(player_id,game_mode )
    local connect = getConnent()
    local database = connect.database 

    --[[
                                (cnt_landlord+cnt_farmer) AS cnt_round,
                                max_cnt_win_win,
                                (cnt_win_landlord+cnt_win_farmer) AS cnt_win_round,
                                cnt_boom,
                                cnt_spring,cnt_farmer_spring,cnt_win_one_two
    ]]
    local query=string.format( [[SELECT cnt_win_win, cnt_lose_lose,
                                max_cnt_win_win, max_times 
                                FROM  total_landlord_statistics WHERE uid=%d and game_mode=%d ]], player_id, game_mode )                           
	local  res = database:query(query)  
    -- debugEx:printdump( res,"UPDATE landlord_statistics:" )  
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
        freeConnect(connect)
		return res.errno,nil
	end
        
    freeConnect(connect)
    return 0, res
end


      
function CMD.game_readTotalStatisticsForAchievement(player_id )
    local connect = getConnent()
    local database = connect.database 

    local query=string.format( [[SELECT sum(cnt_landlord+cnt_farmer) AS sum_cnt_round, 
                                    max(max_cnt_win_win) AS m_max_cnt_win_win, 
                                    sum(cnt_win_landlord+cnt_win_farmer) AS sum_cnt_win_round, 
                                    sum(cnt_boom) AS sum_cnt_boom, 
                                    sum(cnt_spring) AS sum_cnt_spring,
                                    sum(cnt_farmer_spring) AS sum_cnt_farmer_spring,
                                    max(max_times) AS m_max_times,
                                    sum(cnt_win_one_two) AS sum_cnt_win_one_two
                                    FROM  total_landlord_statistics WHERE uid=%d  ]], player_id )                           
	local  res = database:query(query)  
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
        freeConnect(connect)
		return res.errno,nil
	end
        
    freeConnect(connect)
    return 0, res
end

local function l_game_save_money_ren_ren_hero_statistics(  database, player_id,t_game_sts, game_mode )    
    --local connect = getConnent()
    --local database = connect.database 
    do         
        local query=string.format( [[UPDATE hero_statistics 
                                    SET cnt_win_landlord=cnt_win_landlord+%d,cnt_landlord=cnt_landlord+%d,
                                    cnt_win_farmer=cnt_win_farmer+%d,cnt_farmer=cnt_farmer+%d,  
                                    t_cnt = CURRENT_TIMESTAMP(),
                                    t_cnt_win = if( %d>0,CURRENT_TIMESTAMP(),t_cnt_win)
                                    WHERE uid=%d and game_mode=%d and hid=%d ]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,  
                                    t_game_sts.cnt_win,  
                                    player_id, game_mode,  t_game_sts.hero_id )
                                    
	    local res = database:query(query)  
        --print("query", query)
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "A DCGame:l_game_save_money_ren_ren_hero_statistics:query:%s \nres:%s", query , debugEx:dump(res) )

            local query=string.format( [[INSERT INTO hero_statistics( cnt_win_landlord,cnt_landlord,
                                        cnt_win_farmer,cnt_farmer,
                                        t_cnt_win,
                                        uid,game_mode,hid
                                         ) 
                                        VALUES (%d,%d,
                                        %d,%d,
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        %d,%d,%d
                                         )]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,  
                                    t_game_sts.cnt_win,   
                                    player_id, game_mode,  t_game_sts.hero_id )

            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "B DCGame:l_game_save_money_ren_ren_hero_statistics:query:%s \nres:%s", query , debugEx:dump(res) )
                --freeConnect(connect)
                return  2
            end
	    end
    end
    --freeConnect(connect)

    return 0
end
    
local function l_game_save_money_ren_ren_landlord( database, player_id,t_game_sts, game_mode )    
    --local connect = getConnent()
    --local database = connect.database 
log.debug("player_id=%s,t_game_sts=%s, game_mode=%s",debugEx:dump(player_id),debugEx:dump(t_game_sts), debugEx:dump(game_mode))
log.debug("player_id=%s,t_game_sts=%s, game_mode=%s",debugEx:dump(player_id),debugEx:dump(t_game_sts), debugEx:dump(game_mode))
    do         
        local query=string.format( [[UPDATE landlord_statistics 
                                    SET cnt_win_landlord=cnt_win_landlord+%d,cnt_landlord=cnt_landlord+%d,
                                    cnt_win_farmer=cnt_win_farmer+%d,cnt_farmer=cnt_farmer+%d,  
                                     win_gold=win_gold+%d,lose_gold=lose_gold+%d,experience=experience+%d,
                                     win_military_power=win_military_power+%d,lose_military_power=lose_military_power+%d,
                                     online_time = online_time + %d, fee = fee + %d
                                    WHERE uid=%d and game_mode=%d and player_amount=%d and room_times = %d and date = CURRENT_DATE() ]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,   
                                    t_game_sts.win_gold,t_game_sts.lose_gold, t_game_sts.experience,
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power, 
                                    t_game_sts.online_time,t_game_sts.room_fee,
                                    player_id, game_mode, 3, t_game_sts.room_times )
                                    
	    local res = database:query(query)  
        --print("query", query)
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "DCGame:_game_save_money_ren_ren_landlord:query:%s \nres:%s", query , debugEx:dump(res) )

            local query=string.format( [[INSERT INTO landlord_statistics( cnt_win_landlord,cnt_landlord,
                                        cnt_win_farmer,cnt_farmer,

                                        win_gold,lose_gold, experience,
                                        online_time,fee,
                                        uid,game_mode,player_amount,room_times,
                                        date,
                                        win_military_power,lose_military_power 
                                         ) 
                                        VALUES (%d,%d,
                                        %d,%d,
                                        %d,%d,%d ,

                                        %d,%d,
                                        %d,%d,%d,%d,
                                        CURRENT_DATE(),
                                        %d,%d
                                         )]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,   
                                    t_game_sts.win_gold,t_game_sts.lose_gold, t_game_sts.experience,
                                    t_game_sts.online_time,t_game_sts.room_fee,
                                    player_id, game_mode, 3, t_game_sts.room_times,
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power )

            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "DCGame:_game_save_money_ren_ren_landlord:query:%s \nres:%s", query , debugEx:dump(res) )
                --freeConnect(connect)
                return  2
            end
	    end
    end
    --freeConnect(connect)

    return 0
end

local function l_game_save_money_room_free( database, player_id,sts, game_mode )    
    --local connect = getConnent()
    --local database = connect.database 
log.debug("player_id=%s,t_game_sts=%s, game_mode=%s",debugEx:dump(player_id),debugEx:dump(sts), debugEx:dump(game_mode))
    do         
        local query=string.format( [[UPDATE landlord_statistics SET win_gold=win_gold+%d,lose_gold=lose_gold+%d                                      
                                    WHERE uid=%d and game_mode=%d and player_amount=%d and room_times = %d and date = CURRENT_DATE() ]],                                    
                                    sts.win_gold, sts.lose_gold,
                                    player_id, game_mode, sts.player_amount, sts.room_times )
                                    
	    local res = database:query(query)  
        --print("query", query)
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "DCGame:_game_save_money_ren_ren_landlord:query:%s \nres:%s", query , debugEx:dump(res) )

            local query=string.format( [[INSERT INTO landlord_statistics( 
                                        win_gold,lose_gold,                                       
                                        uid,game_mode,player_amount,room_times,date) 
                                        VALUES (%d,%d,                                        
                                        %d,%d,%d,%d,
                                        CURRENT_DATE())]],                                    
                                    sts.win_gold,lose_gold,                                    
                                    player_id, game_mode, sts.player_amount, t_game_sts.room_times)
                                    
            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "DCGame:_game_save_money_ren_ren_landlord:query:%s \nres:%s", query , debugEx:dump(res) )
                --freeConnect(connect)
                return  2
            end
	    end
    end
    --freeConnect(connect)

    return 0
end

local function l_game_save_money_room_free( database, player_id,sts, game_mode )    
    --local connect = getConnent()
    --local database = connect.database 
log.debug("player_id=%s,t_game_sts=%s, game_mode=%s",debugEx:dump(player_id),debugEx:dump(sts), debugEx:dump(game_mode))
    do         
        local query=string.format( [[UPDATE landlord_statistics SET win_gold=win_gold+%d,lose_gold=lose_gold+%d                                      
                                    WHERE uid=%d and game_mode=%d and player_amount=%d and room_times = %d and date = CURRENT_DATE() ]],                                    
                                    sts.win_gold, sts.lose_gold,
                                    player_id, game_mode, sts.player_amount, sts.room_times )
                                    
	    local res = database:query(query)  
        --print("query", query)
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "DCGame:_game_save_money_ren_ren_landlord:query:%s \nres:%s", query , debugEx:dump(res) )

            local query=string.format( [[INSERT INTO landlord_statistics( 
                                        win_gold,lose_gold,                                       
                                        uid,game_mode,player_amount,room_times,date) 
                                        VALUES (%d,%d,                                        
                                        %d,%d,%d,%d,
                                        CURRENT_DATE())]],                                    
                                    sts.win_gold,lose_gold,                                    
                                    player_id, game_mode, sts.player_amount, t_game_sts.room_times)
                                    
            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "DCGame:_game_save_money_ren_ren_landlord:query:%s \nres:%s", query , debugEx:dump(res) )
                --freeConnect(connect)
                return  2
            end
	    end
    end
    --freeConnect(connect)

    return 0
end
    
function CMD.gameSave_ranking( player_id,t_game_sts,game_mode,rankingID )
 

    local connect = getConnent()
    local database = connect.database 
    do         
        local query=string.format( [[UPDATE total_landlord_statistics_ranking  
                                    SET cnt_win_landlord=cnt_win_landlord+%d,cnt_landlord=cnt_landlord+%d,
                                    cnt_win_farmer=cnt_win_farmer+%d,cnt_farmer=cnt_farmer+%d,  

                                    cnt_win_one_two=cnt_win_one_two+%d,
                                    win_gold=win_gold+%d,lose_gold=lose_gold+%d,
                                    win_military_power=win_military_power+%d,lose_military_power=lose_military_power+%d,
                                    cnt_boom=cnt_boom+%d,cnt_spring=cnt_spring+%d,cnt_farmer_spring=cnt_farmer_spring+%d,
                                    cnt_win_win = if( %d>0,cnt_win_win+1,0), cnt_lose_lose=if(%d>0,cnt_lose_lose+1,0),
                                    max_cnt_win_win=if( ( %d>0 and (cnt_win_win) >max_cnt_win_win ), cnt_win_win, max_cnt_win_win ),

                                    max_times = %d,
                                    fee = fee + %d ,
                                    t_cnt_win = if( %d>0,CURRENT_TIMESTAMP(),t_cnt_win),
                                    t_max_cnt_win_win = if( ( %d>0 and cnt_win_win = max_cnt_win_win ),CURRENT_TIMESTAMP(),t_max_cnt_win_win)
                                    WHERE uid=%d and game_mode=%d  and player_amount=3 and rank_id=%d]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,   
                                      
                                    t_game_sts.cnt_win_one_two,
                                    t_game_sts.win_gold,t_game_sts.lose_gold, 
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power, 
                                    t_game_sts.cnt_boom, t_game_sts.cnt_spring, t_game_sts.cnt_farmer_spring, 
                                    t_game_sts.cnt_win, t_game_sts.cnt_lose, 
                                    t_game_sts.cnt_win, 

                                    t_game_sts.max_times,
                                    t_game_sts.room_fee,
                                    t_game_sts.cnt_win,
                                    t_game_sts.cnt_win,
                                    player_id, game_mode,rankingID )
                                    
	    local res = database:query(query)  
       
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
          
            local query=string.format( [[INSERT INTO total_landlord_statistics_ranking( cnt_win_landlord,cnt_landlord,
                                        cnt_win_farmer,cnt_farmer,
                                        cnt_win_one_two,
                                        win_gold,lose_gold, 
                                        cnt_boom, cnt_spring, cnt_farmer_spring,

                                        cnt_win_win,max_cnt_win_win, cnt_lose_lose,
                                        max_times,uid,game_mode,fee,
                                        t_cnt_win, 
                                        t_max_cnt_win_win,
                                        win_military_power,lose_military_power,rank_id ) 

                                        VALUES (%d,%d,
                                        %d,%d,
                                        %d ,
                                        %d,%d,
                                        %d,%d,%d ,

                                         if(%d>0,1,0),if(%d>0,1,0),if(%d>0,1,0),   
                                         %d,%d,%d, %d,
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        %d,%d,%d
                                         )
                                         ]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,     
                                    t_game_sts.cnt_win_one_two,
                                    t_game_sts.win_gold,t_game_sts.lose_gold, 
                                    t_game_sts.cnt_boom, t_game_sts.cnt_spring, t_game_sts.cnt_farmer_spring, 

                                    t_game_sts.cnt_win, t_game_sts.cnt_win, t_game_sts.cnt_lose, 
                                    t_game_sts.max_times, player_id, game_mode ,t_game_sts.room_fee ,
                                    t_game_sts.cnt_win,
                                    t_game_sts.cnt_win,
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power ,rankingID)  

            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                freeConnect(connect)
                return  2
            end
	    end
        
        
    end
    freeConnect(connect)

    return 0
end


function CMD.game_save_money_ren_ren(  player_id,t_game_sts,game_mode )
    log.database("DCGame:game_save_money_ren_ren[%s]:game_mode:%s: %s,%s,%s%s", player_id, game_mode,
                t_game_sts.win_gold,t_game_sts.lose_gold,t_game_sts.win_military_power,t_game_sts.lose_military_power )

    local connect = getConnent()
    local database = connect.database 
    do         
        local query=string.format( [[UPDATE total_landlord_statistics 
                                    SET cnt_win_landlord=cnt_win_landlord+%d,cnt_landlord=cnt_landlord+%d,
                                    cnt_win_farmer=cnt_win_farmer+%d,cnt_farmer=cnt_farmer+%d,  

                                    cnt_win_one_two=cnt_win_one_two+%d,
                                    win_gold=win_gold+%d,lose_gold=lose_gold+%d,
                                    win_military_power=win_military_power+%d,lose_military_power=lose_military_power+%d,
                                    cnt_boom=cnt_boom+%d,cnt_spring=cnt_spring+%d,cnt_farmer_spring=cnt_farmer_spring+%d,
                                    cnt_win_win = if( %d>0,cnt_win_win+1,0), cnt_lose_lose=if(%d>0,cnt_lose_lose+1,0),
                                    max_cnt_win_win=if( ( %d>0 and (cnt_win_win) >max_cnt_win_win ), cnt_win_win, max_cnt_win_win ),

                                    max_times = %d,
                                    fee = fee + %d ,
                                    t_cnt_win = if( %d>0,CURRENT_TIMESTAMP(),t_cnt_win),
                                    t_max_cnt_win_win = if( ( %d>0 and cnt_win_win = max_cnt_win_win ),CURRENT_TIMESTAMP(),t_max_cnt_win_win)
                                    WHERE uid=%d and game_mode=%d  and player_amount=3]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,   
                                      
                                    t_game_sts.cnt_win_one_two,
                                    t_game_sts.win_gold,t_game_sts.lose_gold, 
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power, 
                                    t_game_sts.cnt_boom, t_game_sts.cnt_spring, t_game_sts.cnt_farmer_spring, 
                                    t_game_sts.cnt_win, t_game_sts.cnt_lose, 
                                    t_game_sts.cnt_win, 

                                    t_game_sts.max_times,
                                    t_game_sts.room_fee,
                                    t_game_sts.cnt_win,
                                    t_game_sts.cnt_win,
                                    player_id, game_mode )
                                    
	    local res = database:query(query)  
        --print("query", query)
        --debugEx:printdump( res,"UPDATE landlord_statistics:" )    
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "DCGame:game_save_money_ren_ren:query:%s \nres:%s", query , debugEx:dump(res) )

            local query=string.format( [[INSERT INTO total_landlord_statistics( cnt_win_landlord,cnt_landlord,
                                        cnt_win_farmer,cnt_farmer,
                                        cnt_win_one_two,
                                        win_gold,lose_gold, 
                                        cnt_boom, cnt_spring, cnt_farmer_spring,

                                        cnt_win_win,max_cnt_win_win, cnt_lose_lose,
                                        max_times,uid,game_mode,fee,
                                        t_cnt_win, 
                                        t_max_cnt_win_win,
                                        win_military_power,lose_military_power ) 

                                        VALUES (%d,%d,
                                        %d,%d,
                                        %d ,
                                        %d,%d,
                                        %d,%d,%d ,

                                         if(%d>0,1,0),if(%d>0,1,0),if(%d>0,1,0),   
                                         %d,%d,%d, %d,
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        %d,%d
                                         )
                                         ]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,     
                                    t_game_sts.cnt_win_one_two,
                                    t_game_sts.win_gold,t_game_sts.lose_gold, 
                                    t_game_sts.cnt_boom, t_game_sts.cnt_spring, t_game_sts.cnt_farmer_spring, 

                                    t_game_sts.cnt_win, t_game_sts.cnt_win, t_game_sts.cnt_lose, 
                                    t_game_sts.max_times, player_id, game_mode ,t_game_sts.room_fee ,
                                    t_game_sts.cnt_win,
                                    t_game_sts.cnt_win,
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power )  

            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "must_sql:DCGame:game_save_money_ren_ren:query:%s \nres:%s", query , debugEx:dump(res) )
                freeConnect(connect)
                return  2
            end
	    end
        local l_ret = l_game_save_money_ren_ren_landlord(database, player_id,t_game_sts, game_mode )
        if l_ret ~= 0 then
            --freeConnect(connect)
            --return  3
        end
        local l_ret = l_game_save_money_ren_ren_hero_statistics(database, player_id,t_game_sts, game_mode )
        if l_ret ~= 0 then
            --freeConnect(connect)
            --return  4
        end
    end
    freeConnect(connect)

    return 0
end

function CMD.game_save_money_room(  player_id,t_game_sts,game_mode )
    log.database("DCGame:game_save_money_ren_ren[%s]:game_mode:%s: %s,%s,%s%s", player_id, game_mode,
                t_game_sts.win_gold,t_game_sts.lose_gold,t_game_sts.win_military_power,t_game_sts.lose_military_power )

    local connect = getConnent()
    local database = connect.database 
    do         
        local query=string.format( [[UPDATE total_landlord_statistics 
                                    SET cnt_win_landlord=cnt_win_landlord+%d,cnt_landlord=cnt_landlord+%d,
                                    cnt_win_farmer=cnt_win_farmer+%d,cnt_farmer=cnt_farmer+%d,  

                                    cnt_win_one_two=cnt_win_one_two+%d,
                                    win_gold=win_gold+%d,lose_gold=lose_gold+%d,
                                    win_military_power=win_military_power+%d,lose_military_power=lose_military_power+%d,
                                    cnt_boom=cnt_boom+%d,cnt_spring=cnt_spring+%d,cnt_farmer_spring=cnt_farmer_spring+%d,
                                    cnt_win_win = %d, cnt_lose_lose=if(%d>0,cnt_lose_lose+1,0),
                                    max_cnt_win_win=if( ( %d>0 and (cnt_win_win) >max_cnt_win_win ), cnt_win_win, max_cnt_win_win ),

                                    max_times = %d,
                                    fee = fee + %d ,
                                    t_cnt_win = if( %d>0,CURRENT_TIMESTAMP(),t_cnt_win),
                                    t_max_cnt_win_win = if( ( %d>0 and cnt_win_win = max_cnt_win_win ),CURRENT_TIMESTAMP(),t_max_cnt_win_win)
                                    WHERE uid=%d and game_mode=%d  and player_amount=3]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,   
                                      
                                    t_game_sts.cnt_win_one_two,
                                    t_game_sts.win_gold,t_game_sts.lose_gold, 
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power, 
                                    t_game_sts.cnt_boom, t_game_sts.cnt_spring, t_game_sts.cnt_farmer_spring, 
                                    t_game_sts.cnt_win_win, t_game_sts.cnt_lose, 
                                    t_game_sts.cnt_win, 

                                    t_game_sts.max_times,
                                    t_game_sts.room_fee,
                                    t_game_sts.cnt_win,
                                    t_game_sts.cnt_win,
                                    player_id, game_mode )
                                    
	    local res = database:query(query)  
        --print("query", query)
        --debugEx:printdump( res,"UPDATE landlord_statistics:" )    
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "DCGame:game_save_money_ren_ren:query:%s \nres:%s", query , debugEx:dump(res) )

            local query=string.format( [[INSERT INTO total_landlord_statistics( cnt_win_landlord,cnt_landlord,
                                        cnt_win_farmer,cnt_farmer,
                                        cnt_win_one_two,
                                        win_gold,lose_gold, 
                                        cnt_boom, cnt_spring, cnt_farmer_spring,

                                        cnt_win_win,max_cnt_win_win, cnt_lose_lose,
                                        max_times,uid,game_mode,fee,
                                        t_cnt_win, 
                                        t_max_cnt_win_win,
                                        win_military_power,lose_military_power ) 

                                        VALUES (%d,%d,
                                        %d,%d,
                                        %d ,
                                        %d,%d,
                                        %d,%d,%d ,

                                         if(%d>0,1,0),if(%d>0,1,0),if(%d>0,1,0),   
                                         %d,%d,%d, %d,
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        if( %d>0,CURRENT_TIMESTAMP(),'1999-12-31 23:59:59'),
                                        %d,%d
                                         )
                                         ]],
                                    t_game_sts.cnt_win_landlord,t_game_sts.cnt_landlord,
                                    t_game_sts.cnt_win_farmer,  t_game_sts.cnt_farmer,     
                                    t_game_sts.cnt_win_one_two,
                                    t_game_sts.win_gold,t_game_sts.lose_gold, 
                                    t_game_sts.cnt_boom, t_game_sts.cnt_spring, t_game_sts.cnt_farmer_spring, 

                                    t_game_sts.cnt_win, t_game_sts.cnt_win, t_game_sts.cnt_lose, 
                                    t_game_sts.max_times, player_id, game_mode ,t_game_sts.room_fee ,
                                    t_game_sts.cnt_win,
                                    t_game_sts.cnt_win,
                                    t_game_sts.win_military_power,t_game_sts.lose_military_power )  

            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "must_sql:DCGame:game_save_money_ren_ren:query:%s \nres:%s", query , debugEx:dump(res) )
                freeConnect(connect)
                return  2
            end
	    end
        local l_ret = l_game_save_money_ren_ren_landlord(database, player_id,t_game_sts, game_mode )
        if l_ret ~= 0 then
            --freeConnect(connect)
            --return  3
        end
        local l_ret = l_game_save_money_ren_ren_hero_statistics(database, player_id,t_game_sts, game_mode )
        if l_ret ~= 0 then
            --freeConnect(connect)
            --return  4
        end
    end
    freeConnect(connect)

    return 0
end

function CMD.game_save_money_room_free(  player_id,sts,game_mode )
    log.database("DCGame:game_save_money_room_free[%s]:game_mode:%s: %s,%s", player_id, game_mode, sts.win_gold, sts.lose_gold)

    local connect = getConnent()
    local database = connect.database 
    do         
        local query=string.format("UPDATE total_landlord_statistics SET win_gold=win_gold+%d,lose_gold=lose_gold+%d WHERE uid=%d and game_mode=%d and player_amount=%d,cnt_win_win=0",sts.win_gold, sts.lose_gold, player_id, game_mode, sts.player_amount)                                    
                                    
	    local res = database:query(query)  
        --print("query", query)
        --debugEx:printdump( res,"UPDATE landlord_statistics:" )    
	    if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
            log.database( "DCGame:game_save_money_ren_ren:query:%s \nres:%s", query , debugEx:dump(res) )

            query=string.format( "INSERT INTO total_landlord_statistics(uid, game_mode, win_gold,lose_gold,player_amount,cnt_win_win ) VALUES (%d,%d,%d,%d,%d,0)", 
								 player_id, game_mode,sts.win_gold,sts.lose_gold,sts.player_amount)
             local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "must_sql:DCGame:game_save_money_ren_ren:query:%s \nres:%s", query , debugEx:dump(res) )
                freeConnect(connect)
                return  2
            end
	    end
        local l_ret = l_game_save_money_room_free(database, player_id,t_game_sts, game_mode )
        if l_ret ~= 0 then
            --freeConnect(connect)
            --return  3
        end
    end
    freeConnect(connect)

    return 0
end
    
function CMD.game_save_money_ranking(  player_id,t_game_sts,game_mode,matchID )
    local matchID=matchID or -1
    if matchID>1 then
        CMD.gameSave_ranking( player_id,t_game_sts,game_mode,matchID )
    end

    return CMD.game_save_money_ren_ren(  player_id,t_game_sts,game_mode )
end

function CMD.game_detail_log(  player_id,t_detail_sts,game_mode )
    local connect = getConnent()
    local database = connect.database 
    do         
            local query=string.format( [[INSERT INTO landlord_detail_log( 
                                        uid,game_mode,
                                        room_times,room_id,content ) 
                                        VALUES (%d,%d,
                                        %d,%d,'%s'
                                         )
                                         ]],
                                    player_id,game_mode,
                                    t_detail_sts.room_times, t_detail_sts.room_id, t_detail_sts.content )  
            local res = database:query(query)  
            if next(res)==nil or not res.affected_rows or res.affected_rows ~= 1 then  
                log_imp2( "DCGame:game_detail_log:query:%s \nres:%s", query , debugEx:dump(res) )
                freeConnect(connect)
                return  2
            end
    end
    freeConnect(connect)

    return 0
end
--[=[
function CMD.game_test_detail_log(  player_id, game_mode )
    local connect = getConnent()
    local database = connect.database 

    local res
    do         
            local query=string.format( [[SELECT content FROM landlord_detail_log WHERE uid=%d AND game_mode = %d
                                         ]],
                                    player_id,game_mode )  
            res = database:query(query)  
            
            if next(res)==nil then  
                log.database( "DCGame:game_detail_log:query:%s \nres:%s", query , debugEx:dump(res) )
                freeConnect(connect)
                return  2
            end

            print(res[1].content)
    end
    freeConnect(connect)

    return 0,res
end
]=]

function CMD.game_GetEventValue(uid)
	local connect = getConnent()
	local database = connect.database 
	
	print("DC:game_GetEventValue():")
--                          101:game_cnt    102:win_continue_max, 103:win cnt max, 104: boom cnt,105:spring cnt, 106: farmer spring cnt,107:max times,108:cnt win on one two,126:cnt master,127:cnt roomer
	local query="SELECT SUM(cnt_landlord)+SUM(cnt_farmer) AS '101', MAX(max_cnt_win_win) AS '102', SUM(cnt_win_landlord)+ SUM(cnt_win_farmer) AS '103',SUM(cnt_boom) AS '104', SUM(cnt_spring) AS '105',SUM(cnt_farmer_spring) AS '106',MAX(max_times) AS '107',SUM(cnt_win_one_two) AS '108',SUM(cnt_master) AS '126',SUM(cnt_roomer) AS '127' FROM total_landlord_statistics WHERE uid="..uid.." GROUP BY uid;SELECT combination_id FROM hero_combination_log WHERE uid="..uid
	local res = database:query(query)  
	freeConnect(connect)
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return res.errno,nil
	end
	if  not res.mulitresultset or res.mulitresultset ~= true then	
		log.error("sql erro:sqld:%s\n,res:%s",query,debugEx:dump( res ))	
		return 10,nil
	end

	log.debug("sql debug:sql:%s\n,res:%s",query,debugEx:dump( res ))	

	local event={}
	if res[1] and res[1][1] then
		for k,v in pairs(res[1][1]) do
			event[ tonumber(k) ]=v
		end
	end

	if res[2] then
		for _,v in ipairs(res[2]) do
			event[v.combination_id]=1
		end
	end
	return 0,event
end
    
function CMD.game_get_android_config(game_mode)
    local ret =  0
    local connect = getConnent()
    local database = connect.database 
    local res = {}

    do
        local query=string.format(  
        [[SELECT game_mode, is_enable, max_win, max_lose
          FROM android_config 
          WHERE game_mode = %d]]
           ,game_mode  )
	    local result = database:query(query)  
	    if next(result)==nil  then  
            log.database("sql error: sql:%s , result: ", query, debugEx:dump( result )  )
            ret =  1
	    end
        res = result
    end
        
    freeConnect(connect)
    
    return ret,res
end
    
function CMD.game_get_android_total_losewin(game_mode)
    local connect = getConnent()
    local database = connect.database 
    local ret =  0
    local res = {}

    do
        local query=string.format(  
        [[SELECT (win_gold-lose_gold) AS total_losewin_gold
          FROM total_landlord_statistics 
          WHERE game_mode = %d and uid IN (SELECT uid FROM android_list)]]
           ,game_mode  )
	    local result = database:query(query)  
	    if next(result)==nil  then  
            log.database("sql error: sql:%s , result: ", query, debugEx:dump( result )  )
            ret =  1
	    end
        res = result
    end
        
    freeConnect(connect)
    
    return ret,res
end

--[[
--使用示例:
local roundInfo={}
roundInfo.unique_room_id=10  --房间ID(全局唯一,redis房间信息中字段 unique_room_idINT) 
roundInfo.game_mode=4        --1:人人模式,2:人机模式;3:排位赛;4:好友模式;5:比赛
roundInfo.times=10           --房间倍率或nil

local usersInfo={}
local user1={}
local user2={}

user1.uid=10001         --玩家id
user1.obtain= -100      --获得分数 (nil:不填)
user1.nickname='name'   --玩家昵称 (nil:不填)
user1.role=1            --1:地主 2:农民 (nil:不填)
user1.hero=0            --英雄id(0:表示不使用英雄,nil:不填)
user2.uid=10002
user2.obtain= -100
user2.nickname='name2'
user2.role=1
user2.hero=0

usersInfo[#usersInfo+1]=user1
usersInfo[#usersInfo+1]=user2

CMD.game_log_end(roundInfo,usersInfo) --失败返回 nil 成功返回 round_id
]]

function CMD.game_log_end(roundInfo,usersInfo)
    if roundInfo==nil or usersInfo==nil then
        return nil
    end
    local room_id=roundInfo.room_id or -1
    local game_mode=roundInfo.game_mode or -1
   -- local pay_currency=roundInfo.roundInfo or -1
    local times=roundInfo.times or -1
    local unique_room_id=roundInfo.unique_room_id or -1
    --local reusable_room_id=roundInfo.reusable_room_id or -1

    local query=string.format("INSERT INTO round_history(unique_room_id,game_mode,times) VALUES(%d,%d,%d);", unique_room_id,game_mode,times) --SELECT LAST_INSERT_ID() as round_id;
    
    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)
    
    if res.errno ~=nil or res.insert_id==nil then
        freeConnect(connect)
        log.database("sql error: sql:%s , result: ", query, debugEx:dump( res )  )
        log.log('res:%s',log.dump(res))
        log.error('res:%s',log.dump(res))
        return nil
    end

    local round_id=res.insert_id
    local usersQuery=""
    for k,v in ipairs(usersInfo) do
        local uid=v.uid or -1
        local obtain=v.obtain or 0
        local nickname=v.nickname or ''
        local role=v.role or -1
        local hero=v.hero or -1
        local oneQuery =string.format("INSERT INTO obtain_history(round_id,uid,obtain,nickname,role,hero) VALUES(%d,%d,%d,'%s',%d,%d);",round_id,uid,obtain,nickname,role,hero)
        usersQuery =usersQuery..oneQuery
    end
    
    local res = database:query(usersQuery)

    if res.errno ~=nil then
        freeConnect(connect)
        log.database("sql error: sql:%s , result: ", usersQuery, debugEx:dump( res )  )
        log.log('res:%s',log.dump(res))
        log.error('res:%s',log.dump(res))
        return nil
    end

	freeConnect(connect)
    return round_id
end

--[[
--使用示例:
local roomInf={}
roomInf.reusable_room_id=660005  --玩家视觉房间id (房间解散后，可被重复使用)
roomInf.owner_uid=1001           --房主
roomInf.rounds =24              --最大局数
roomInf.hero_enable =1          --武将，1:启用，0:不启用
roomInf.entry_card_enable =1    --计牌器，1:启用，0:不启用
roomInf.pay_currency =1        --支付货币(0:积分 1:铜钱)
roomInf.base     =10           --底分
roomInf.gold_min   =0          --铜钱下限，<0表示不限制，如果是积分结算，可以为nil
roomInf.gold_max   =0          --铜钱上限，<0表示不限制，如果是积分结算，可以为nil

CMD.game_log_room_create(roomInf)
--成功返回 unique_room_id,否则返回nil
]]
function CMD.game_log_room_create(roomInf)

    local reusable_room_id =roomInf.reusable_room_id or -1
    local owner_uid=roomInf.owner_uid or -1
    local rounds=roomInf.rounds or -1
    local hero_enable=roomInf.hero_enable or -1
    local entry_card_enable=roomInf.entry_card_enable or -1
    local pay_currency=roomInf.pay_currency or -1
    local base=roomInf.base or -1
    local gold_min=roomInf.gold_min or -1
    local gold_max=roomInf.gold_max or -1
    
    local query=string.format("INSERT INTO room_create_log(reusable_room_id,owner_uid,rounds,hero_enable,entry_card_enable,pay_currency,base,gold_min,gold_max) VALUES(%d,%d,%d,%d,%d,%d,%d,%d,%d);"
                                    ,reusable_room_id,owner_uid,rounds,hero_enable,entry_card_enable,pay_currency,base,gold_min,gold_max)

    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)
    if res.errno ~=nil or res.insert_id==nil then
        freeConnect(connect)
        log.database("sql error: sql:%s , result: ", query, debugEx:dump( res )  )
        log.log('res:%s',log.dump(res))
        log.error('res:%s',log.dump(res))
        return nil
    end

    freeConnect(connect)
    local unique_room_id=res.insert_id
    return unique_room_id
end

function CMD.get_room_play_back_info(uid)
    local connect = getConnent()
	local database = connect.database
    local relateRoomQuery=string.format("SELECT unique_room_id FROM round_history as r  LEFT JOIN obtain_history as o ON r.round_id=o.round_id where game_mode=4 AND uid=%d GROUP BY unique_room_id ORDER BY r.round_id DESC limit 10",uid)
    local res = database:query(relateRoomQuery)
    if res.errno ~=nil then
        freeConnect(connect)
        log.database("sql error: sql:%s , result: ", relateRoomQuery, debugEx:dump( res )  )
        log.log('res:%s',log.dump(res))
        log.error('res:%s',log.dump(res))
        return nil
    end
    if #res==0 then
        freeConnect(connect)
        return {}
    end
    local inCondition="("
    for k,v in ipairs(res) do
        if k ~= #res then
            inCondition=inCondition ..tostring(v.unique_room_id)..","
        else
            inCondition=inCondition ..tostring(v.unique_room_id)..")"
        end
    end

    local roomsInfoQuery="SELECT *,UNIX_TIMESTAMP(create_time) as unix_create_time FROM room_create_log WHERE unique_room_id IN "..inCondition
    local res = database:query(roomsInfoQuery)
    if res.errno ~=nil then
        freeConnect(connect)
        log.database("sql error: sql:%s , result: ", roomsInfoQuery, debugEx:dump( res )  )
        log.log('res:%s',log.dump(res))
        log.error('res:%s',log.dump(res))
        return nil
    end

    local roomInfoByURoomID={}
    for _,v in ipairs(res) do
        roomInfoByURoomID[v.unique_room_id]=v
    end


    local roundInfoQuery="SELECT r.round_id,r.unique_room_id,r.create_time,UNIX_TIMESTAMP(r.create_time) as unix_create_time,uid,obtain,nickname FROM round_history as r LEFT JOIN obtain_history as o ON r.round_id=o.round_id WHERE unique_room_id IN "..inCondition
    local res = database:query(roundInfoQuery)
    if res.errno ~=nil then
        freeConnect(connect)
        log.database("sql error: sql:%s , result: ", roundInfoQuery, debugEx:dump( res )  )
        log.log('res:%s',log.dump(res))
        log.error('res:%s',log.dump(res))
        return nil
    end

    --[[
        indexTable[600002] = {usersObtainTotal={},roundsInfo={}}
    ]]

    local indexTable={}
    local uidToNickname={}
    for k,v in ipairs(res) do
        local uRoomID=v.unique_room_id
        local roundID=v.round_id
        indexTable[uRoomID]=indexTable[uRoomID] or {usersObtainTotal={},roundsInfo={}}
        local simp =indexTable[uRoomID]
        simp.usersObtainTotal[v.uid] =(simp.usersObtainTotal[v.uid] or 0) +v.obtain
        simp.roundsInfo[v.round_id]=simp.roundsInfo[v.round_id] or {}
        simp.roundsInfo[v.round_id][v.uid]=v
        uidToNickname[v.uid]=v.nickname
    end

    local list_info={}
    for uRoomID,roomInfo in pairs(indexTable) do
        local compete={}
        compete.room_id=(roomInfoByURoomID[uRoomID] or {}).reusable_room_id or -1
        compete.timestamp=(roomInfoByURoomID[uRoomID] or {}).unix_create_time or 0
        compete.result=(roomInfoByURoomID[uRoomID] or {}).pay_currency or -1 
        compete.summation={}
        for uid,obtainTotal in pairs(roomInfo.usersObtainTotal) do
            compete.summation[#compete.summation+1]={uid=uid,nickname=uidToNickname[uid],obtain_total=obtainTotal}
        end
        compete.details={}

       -- local roundDex=1
        for roundID,roundinfo in pairs(roomInfo.roundsInfo) do
            local temItem ={round=nil,users_obtain={}}
            for uid,obtainInfo in pairs(roundinfo) do
                temItem.users_obtain[#temItem.users_obtain+1]={uid=obtainInfo.uid,obtain=obtainInfo.obtain}
                temItem.timestamp=obtainInfo.unix_create_time --联表查询，所以多条记录的时间是一样的
            end
            compete.details[#compete.details+1]=temItem
           -- roundDex=roundDex+1
        end
        table.sort(compete.details,function(a,b)return a.timestamp< b.timestamp end )
        for k,v in ipairs(compete.details) do
            v.round=k
        end
        list_info[#list_info+1]=compete
    end
    freeConnect(connect)

    table.sort(list_info,function(a,b)return a.timestamp> b.timestamp end )
    return list_info

    --[[
    local list_info={}
    for i=1,5 do
        local compete={}
        compete.room_id=500000+i
        compete.timestamp="2017-10-21 15:14:45"
        compete.result=0
        compete.summation={}
            compete.summation[1]={uid=self.uid,nickname=this.inf.nickname,obtain_total=10}
            compete.summation[2]={uid=3001,nickname='路人1',obtain_total=10}
            compete.summation[3]={uid=3002,nickname='路人2',obtain_total=-20}
        compete.details={}
            for j=1,3 do
                compete.details[j]={round=j,timestamp="2017-10-21 15:14:45",users_obtain={}}
                compete.details[j].users_obtain[1]={uid=self.uid,obtain=10}
                compete.details[j].users_obtain[2]={uid=3001,obtain=10}
                compete.details[j].users_obtain[3]={uid=3002,obtain=-10}
            end
        list_info[i]=compete
    end
   ]]
end

--[[
--使用示例
    CMD.get_ranking_list_of_wincnt("2017-11-01 00:00:01","2017-11-30 23:59:59",100) --错误返回nil
--成功返回示例,返回 时间timestart到timeend的好友房胜利场数排行榜
    {
        {uid=7481,wincnt=11,ct="2017-11-01 01:00:01"},
        {uid=7482,wincnt=8,ct="2017-11-01 02:00:01"},
        {uid=7483,wincnt=7,ct="2017-11-01 02:00:01"}
    }
]]
function CMD.get_ranking_list_of_wincnt(timestart,timeend,limitcnt)

    local timestart=timestart or "2017-11-01 00:00:01"
    local timeend=timeend or "2017-11-30 23:59:59"
    local limitcnt=limitcnt or 100

    local query =string.format('SELECT uid,COUNT(*) as wincnt,MAX(create_time) as ct  FROM round_history as r LEFT JOIN obtain_history as o ON r.round_id=o.round_id \z 
                                    WHERE game_mode=4 AND obtain>0 AND create_time>"%s" AND create_time<"%s" GROUP BY uid ORDER BY wincnt desc,ct LIMIT %d',timestart,timeend,limitcnt)

    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)
    freeConnect(connect)
    if res.errno ~=nil then
        log.database("sql error: sql:%s , result:%s ", query, debugEx:dump( res )  )
        log.log('res:%s query:%s',log.dump(res),query)
        log.error('res:%s query:%s',log.dump(res),query)
        return nil
    end
   
   return res
end


--SELECT COUNT(*) as obtain_sum FROM round_history as r LEFT JOIN obtain_history as o ON r.round_id=o.round_id WHERE o.uid=7483 AND (r.game_mode<>2) AND r.create_time>"2017-02-21 10:34:51" and r.create_time<"2018-02-26 10:34:51"


--[[
    获得uid在时间timestart到timeend内在非人机模式下的游戏次数
]]
function CMD.get_play_cnt(uid,timestart,timeend)
    local query =string.format( 'SELECT COUNT(*) as obtain_sum FROM round_history as r LEFT JOIN obtain_history as o ON r.round_id=o.round_id WHERE o.uid=%d AND (r.game_mode<>2) AND r.create_time>"%s" and r.create_time<"%s"',uid,timestart,timeend)

    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)
   
    freeConnect(connect)
    if res.errno ~=nil then
        log.database("sql error: sql:%s , result:%s ", query, debugEx:dump( res )  )
        log.log('res:%s query:%s',log.dump(res),query)
        log.error('res:%s query:%s',log.dump(res),query)
        return nil
    end

    if #res ==0 then
        return 0
    end

    return res[1].obtain_sum or 0
end

--[[
    获得uid在时间timestart到timeend内在匹配和排位获得的金钱总数
]]
function CMD.get_obtain_sum(uid,timestart,timeend)
   local query =string.format( 'SELECT sum(o.obtain) as obtain_sum FROM round_history as r LEFT JOIN obtain_history as o ON r.round_id=o.round_id WHERE o.uid=%d AND (r.game_mode=1 OR  r.game_mode=4) AND r.create_time>"%s" and r.create_time<"%s" and o.obtain>0',uid,timestart,timeend)

    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)
   
    freeConnect(connect)
    if res.errno ~=nil then
        log.database("sql error: sql:%s , result:%s ", query, debugEx:dump( res )  )
        log.log('res:%s query:%s',log.dump(res),query)
        log.error('res:%s query:%s',log.dump(res),query)
        return nil
    end

    if #res ==0 then
        return 0
    end

    return res[1].obtain_sum or 0
end


--[[
   获得uid在时间 timestart到timeend内获得的糖果数(每玩一局非人机可得一个，每日上限为daylimit个)
   错误返回nil,成功返回糖果数
]]
function CMD.get_candy_total(uid,timestart,timeend,daylimit)
    local timestart=timestart or "2017-11-01 00:00:01"
    local timeend=timeend or "2017-11-14 23:59:59"
    local daylimit=daylimit or 20

    local query =string.format('SELECT  DATE(create_time) as dt,COUNT(*) as playcnt FROM round_history as r LEFT JOIN obtain_history as o ON r.round_id=o.round_id WHERE create_time>"%s" \z
                                        AND create_time<"%s" AND uid=%d and game_mode <>2 and obtain <>0 GROUP BY dt',timestart,timeend,uid)

    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)
     freeConnect(connect)
    if res.errno ~=nil then
        log.database("sql error: sql:%s , result:%s ", query, debugEx:dump( res )  )
        log.log('res:%s query:%s',log.dump(res),query)
        log.error('res:%s query:%s',log.dump(res),query)
        return nil
    end

    log.log("query:%s",query)
    local candycnt=0
    local resByDT={}
    for k,v in ipairs(res) do
        if v.playcnt <daylimit then
            candycnt =candycnt +v.playcnt
        else
            candycnt =candycnt +daylimit
        end
        resByDT[v.dt]=v
    end

    return candycnt,resByDT
end

 --[[
 #武将基本信息
.HERO_HAVE_BASE_INF {
	id 0:integer
}

#玩家游戏详细信息
.USER_GAME_INF {
	cnt_landlord 0:integer	#地主场数 --
	cnt_farmer 1:integer	#农民场数 --
	win_landlord 2:integer	#地主胜利场数 --
	win_farmer 3:integer	#农民胜利场数--
	win_max 4:integer	#最大连胜场数 --
	springs 5:integer	#春天	--
	unsprings 6:integer	#反春天 --
	booms 7:integer		#炸弹	--
	cnt_hero 8:integer	#武将数量
	cnt_skin 9:integer	#皮肤数量
	military_rank_max 10: integer	#最高军阶
	hero_often 11: *HERO_HAVE_BASE_INF	#常用武将
}
	["win_farmer"] = 0,
			["springs"] = 0,
			["booms"] = 1,
			["cnt"] = 10,
			["win_max"] = 1,
			["unsprings"] = 2,
			["win_landlord"] = 10,
 ]]   


--常用英雄:  { {hid=1,cnt=8,wincnt=9},{hid=1,cnt=3,wincnt=9} }
local function freqUseHeroList(uid)
    local connect = getConnent()
	local database = connect.database 
    local query=string.format("select hid,cnt_landlord,cnt_farmer,cnt_win_landlord,cnt_win_farmer from hero_statistics where uid=%d and hid>0",uid)
    local res = database:query(query)  
	freeConnect(connect)

    if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return nil
	end

    local heroToPlayCnt={}
    local heroToWinCnt={}
    for _,v in ipairs(res) do
        local playCnt=v.cnt_landlord+v.cnt_farmer 
        local winCnt=v.cnt_win_landlord +v.cnt_win_farmer

        heroToPlayCnt[v.hid] = (heroToPlayCnt[v.hid] or 0) + playCnt
        heroToWinCnt[v.hid] = (heroToWinCnt[v.hid] or 0) + winCnt
    end

    local heroInfoList={}
    for k,v in pairs(heroToPlayCnt) do
        heroInfoList[#heroInfoList+1]={hid=k,cnt=v,wincnt=heroToWinCnt[k]}
    end

    table.sort(heroInfoList,function(a,b)return tonumber(a.cnt)> tonumber(b.cnt) end )
    return heroInfoList
   -- return { (heroInfoList[1] or {}).hid, (heroInfoList[2] or {}).hid, (heroInfoList[3] or {}).hid }

end

local function userGameInf(uid)
    local connect = getConnent()
	local database = connect.database 

    local query=string.format("SELECT SUM(cnt_landlord) AS cnt_landlord,SUM(cnt_farmer) AS cnt_farmer, SUM(cnt_win_landlord) AS win_landlord,\z
                    SUM(cnt_win_farmer) AS win_farmer, MAX(max_cnt_win_win) AS win_max,SUM(cnt_boom) AS booms, SUM(cnt_spring) AS springs,\z
                    SUM(cnt_farmer_spring) AS unsprings FROM total_landlord_statistics WHERE uid=%d GROUP BY uid",  uid)

    local res = database:query(query)  
	freeConnect(connect)
     if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return nil
	end

    return res[1]
end


function CMD.lobby_GameInfList(uid)
    local freqHeroList=freqUseHeroList(uid)
    if not freqHeroList then
        return 1,nil
    end

    local  freqUserThreeHero={}
    for i=1,3 do
        if not freqHeroList[i] then break end
        freqUserThreeHero[#freqUserThreeHero+1]={id=freqHeroList[i].hid}
    end
   -- freqUserThreeHero={ {id=(freqHeroList[1] or {}).hid}, {id=(freqHeroList[2] or {}).hid}, {id=(freqHeroList[3] or {}).hid}  }

    local gameInf=userGameInf(uid)
    if not gameInf then
        gameInf={}
		gameInf.cnt_farmer = 0
		gameInf.cnt_landlord = 0
		gameInf.win_max = 0
		gameInf.win_farmer = 0
		gameInf.win_landlord = 0
		gameInf.springs = 0		
		gameInf.unsprings = 0
		gameInf.booms = 0
    end

    return 0,freqUserThreeHero,gameInf
end


--[[
function CMD.lobby_GameInfList(uid)

    do return 0,{},{} end

	local connect = getConnent()
	local database = connect.database 
	
	print("DC:lobbyGameInfList():")

	local q1="SELECT hid AS id FROM hero_statistics WHERE uid="..uid.." ORDER BY cnt_match+cnt_friend+cnt_ranking+cnt_race  DESC LIMIT 3"
	local q2="; SELECT SUM(cnt_landlord) AS cnt_landlord,SUM(cnt_farmer) AS cnt_farmer, SUM(cnt_win_landlord) AS win_landlord,SUM(cnt_win_farmer) AS win_farmer, MAX(max_cnt_win_win) AS win_max,SUM(cnt_boom) AS booms, SUM(cnt_spring) AS springs,SUM(cnt_farmer_spring) AS unsprings FROM total_landlord_statistics WHERE uid="..uid.." GROUP BY uid"
	local query = q1..q2
	local res = database:query(query)  
	freeConnect(connect)
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return res.errno,nil
	end
	if  not res.mulitresultset or res.mulitresultset ~= true then	
		log.error("sql erro:sqld:%s\n,res:%s",query,debugEx:dump( res ))	
		return 10,nil
	end

	log.debug("sql debug:sql:%s\n,res:%s",query,debugEx:dump( res ))

	if not res[1] or not res[2] then
		log.error("no game inf")	
		return 1
	end

	local game
	if res[2][1] then
		game=res[2][1]
	else
		game={}
		game.cnt_farmer = 0
		game.cnt_landlord = 0
		game.win_max = 0
		game.win_farmer = 0
		game.win_landlord = 0
		game.springs = 0		
		game.unsprings = 0
		game.booms = 0
	end
	
	return 0,res[1],game
end
  
]]

--[[
	cnt_landlord 0:integer	#地主场数
	cnt_farmer 1:integer	#农民场数
	win_landlord 2:integer	#地主胜利场数
	win_farmer 3:integer	#农民胜利场数
]]
function CMD.lobby_PerHeroStatistics(uid,sid)
	local connect = getConnent()
	local database = connect.database 
	
	print("DC:PerHeroStatistics():")

	local query=string.format("SELECT cnt_landlord, cnt_farmer, cnt_win_landlord,cnt_win_farmer FROM hero_statistics WHERE uid=%d AND hid=%d AND game_mode<>2",uid,sid)
	local res = database:query(query)  
	freeConnect(connect)
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return res.errno,nil
	end

	log.debug("sql debug:sql:%s\n,res:%s",query,debugEx:dump( res ))
	if next(res)==nil then
		return 0,{cnt_landlord=0,cnt_farmer=0,win_landlord=0,win_farmer=0}
	end

    local rlt={}
    rlt.cnt_landlord=0
    rlt.cnt_farmer=0
    rlt.cnt_win_landlord=0
    rlt.cnt_win_farmer=0

    for k,v in ipairs(res) do
        rlt.cnt_landlord=rlt.cnt_landlord +v.cnt_landlord
        rlt.cnt_farmer=rlt.cnt_farmer +v.cnt_farmer
        rlt.cnt_win_landlord=rlt.cnt_win_landlord +v.cnt_win_landlord
        rlt.cnt_win_farmer=rlt.cnt_win_farmer +v.cnt_win_farmer
    end

	return 0,rlt
end
  
--胜率
local function userWinRate(uid)
    local connect = getConnent()
	local database = connect.database 
    local query =string.format("SELECT SUM(cnt_landlord)+SUM(cnt_farmer) AS cnt, SUM(cnt_win_landlord)+ SUM(cnt_win_farmer) AS win_cnt FROM total_landlord_statistics WHERE uid=%d GROUP BY uid",uid)
    local res = database:query(query)  
    freeConnect(connect)
    if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return 0
	end

    if not res[1] then return 0 end
    
    local cnt=res[1].cnt or 0
    local wincnt=res[1].win_cnt or 0
    
    if cnt==0 then return 0 end
    
    local winRate=(wincnt*100)//cnt
    log.debug("wincnt:%d cnt:%d winRate:%d type:%s",wincnt,cnt,winRate,math.type(winRate))
    return winRate
end

--[[
.PLAYER_RESULT_INF {
	id 0:	integer	#局id
	name 1:	integer	#名称，如 天梯排名
	play_result 2:	integer	#结果1:win ,2:lose
	rule 3:	integer	#角色，1:地主，2：农民
	time 4:	string	#时间
	hero_id 5:	integer	#使用武将ID，0表示未使用
}
]]
--[[

{"inf":[ 
{"id":7023,"name":"ゞ痴心╰つ","det_score":0,"is_win":true,"is_landlord":false},
{"id":7003,"name":"安ぷ诺","det_score":0,"is_win":false,"is_landlord":true},
{"id":5735058,"name":"ji蛋二货","det_score":0,"is_win":true,"is_landlord":false} 
]}

]]
local function userHistoryTen(uid)

   local infs= CMD.lobby_playbackinfs(uid)
   if not infs then return {} end

   local historys={}

   for k,v in ipairs(infs) do
      local item={}
      item.id=#historys +1
      item.name=v.game_mode
      item.time=v.timestamp

      local contentTable=  json.decode(v.content)
      if contentTable==nil or type(contentTable) ~='table' then
        log.debug("content may not json string:%s",v.content)
        log.log("content may not json string:%s",v.content)
        return {}
      end

      local selfItem={}
      for _,vv in ipairs(contentTable.inf) do
        if vv.id==uid then
            selfItem=vv
        end
      end

      if selfItem.is_win then
        item.play_result=1
      else
       item.play_result=0
      end

      if selfItem.is_landlord then
        item.rule=1
      else
        item.rule=0
      end
      item.hero_id=selfItem.hero_id or 11

      historys[#historys+1]=item
   end
   return historys
   
  -- json.decode(inf.products)
--[[
    local connect = getConnent()
	local database = connect.database 
    local query =string.format("SELECT content FROM player_game_log WHERE uid=%d",uid)
    local res = database:query(query)  
    freeConnect(connect)

    if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return {}
	end    

    if not res[1] then return {} end
    if not res[1].content then return {} end

    local history_ten={}
    for mode,role,result,hero,time in string.gmatch(res[1].content,"(%d+),(%d+),(%d+),(%d+),(%d+);") do
			history_ten[#history_ten + 1]={id=#history_ten+1,name=mode,play_result=result,rule=role,hero_id=hero,time=time}
	end

    return history_ten
    ]]
end


function CMD.lobby_GameHistoryList(uid)
    
    local historyTen=userHistoryTen(uid)
    local winRate=userWinRate(uid)
    local freqUseHero= freqUseHeroList(uid) --{ {hid=1,cnt=8,wincnt=9},{hid=1,cnt=3,wincnt=9} }

    local hero_use={}
    for _,v in ipairs(freqUseHero) do
        local heroWinRate=0
        if v.cnt >0 then 
            heroWinRate=(v.wincnt*100)//v.cnt 
        end
        hero_use[#hero_use+1]={id=v.hid,use_cnt=v.cnt,win_per=heroWinRate,sid=v.hid+5000} --缺了个皮肤不知道怎么赋值
    end

 
  return 0,historyTen,{hero_use[1],hero_use[2],hero_use[3]},winRate
end

--gamemode 1:人人模式,2:人机模式;3:排位赛;4:好友模式;5:比赛
function CMD.lobby_TotalLandlordStatistics(uid,gamemode)
    if not uid or not gamemode then return nil end

    local connect = getConnent()
	local database = connect.database 

    local query=string.format("select * from total_landlord_statistics where uid=%d and game_mode=%d",uid,gamemode)

    local res = database:query(query)
    freeConnect(connect)
    if res.errno ~= nil then
		log.error("sql error: sql:%s,ret:%s",query,debugEx:dump( res ) )	
		return nil
	elseif  next(res)==nil and #res ~= 1 then
		log.error("sql no equ 1 error: sql:%s,ret:%s",query,debugEx:dump( res ) )	
		return nil
	end		

    return res[1]
end


--[==[
function CMD.lobby_GameHistoryList(uid)

	local connect = getConnent()
	local database = connect.database 
	
	print("DC:lobbyGeUseGameAction():")

	local q1="SELECT content FROM player_game_log WHERE uid="..uid
	local q2="; SELECT hid,cnt_landlord+cnt_farmer AS cnt,cnt_win_landlord+cnt_win_farmer AS win FROM hero_statistics WHERE uid="..uid.." ORDER BY cnt  DESC LIMIT 3"
	local q3="; SELECT SUM(cnt_landlord)+SUM(cnt_farmer) AS cnt, SUM(cnt_win_landlord)+ SUM(cnt_win_farmer) AS win_cnt FROM total_landlord_statistics WHERE uid="..uid.." GROUP BY uid"
   -- local q4="; select hid,sid from list_hero where uid="..uid
	local query = q1..q2..q3 --..q4
	local res = database:query(query)  
	freeConnect(connect)
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return res.errno,nil
	end
	if  not res.mulitresultset or res.mulitresultset ~= true then	
		log.error("sql erro:sqld:%s\n,res:%s",query,debugEx:dump( res ))	
		return 10,nil
	end

	log.debug("sql debug:sql:%s\n,res:%s",query,debugEx:dump( res ))	

	local history_ten={}
--[[
id 0:	integer	#局id
	name 1:	integer	#名称，如 天梯排名
	play_result 2:	integer	#结果1:win ,2:lose
	rule 3:	integer	#角色，1:地主，2：农民
	time 4:	string	#时间
	hero_id 5:	integer	#使用武将ID，0表示未使用
]]
	if res[1][1] and res[1][1].content then
		--for mode,role,result,hero,time in string.gmatch(res[1][1].content,"(%d+),(%d+),(%d+),(%d+);") do
		for mode,role,result,hero,time in string.gmatch(res[1][1].content,"(%d+),(%d+),(%d+),(%d+),(%d+);") do
			--print("==========t:",mode,role,result,hero,time)
			history_ten[#history_ten + 1]={id=#history_ten+1,name=mode,play_result=result,rule=role,hero_id=hero,time=time}
		end
	end
	--log.debug("history_ten:%s",debugEx:dump( history_ten ))
--[[
	id 0:	integer	#武将ID
	use_cnt 1: integer	#使用次数
	win_per 2: integer	#胜率
]]

    local hid_sid={}
    if res[4] then
        for _,v in ipairs(res[4]) do
            hid_sid[v.hid]=v.sid
        end
    end

	local hero_use={}
	if res[2] then
		for _,v in ipairs(res[2]) do
			if v.cnt == 0 then
				v.cnt=1
			end
			hero_use[#hero_use+1]={id=v.hid,use_cnt=v.cnt,win_per=v.win/v.cnt,sid=hid_sid[v.hid]}
		end
	end
	--log.debug("hero_use:%s",debugEx:dump( hero_use ))

	local win_per=0
	if res[3] and res[3][1] then
		local t = res[3][1]
		local m = t.win_cnt or 1
		if m == 0 then
			m=1
		end
		win_per = (t.win_cnt or 0)/m
	end	

	return 0,history_ten,hero_use,win_per
end
]==]

local function lobby_Order_Templet( str )
	local connect = getConnent()
	local database = connect.database 

	local query=str
	local res = database:query(query) 
--log.debug("sql str: %s\nsqlret:%s", debugEx:dump( query ),debugEx:dump( res ))	
	if  res.errno ~= nil then
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		freeConnect(connect)
		return res.errno,"db err" 
	end
	
	freeConnect(connect)	

	return 0,res
end


function CMD.lobby_Order_Win( )
	return lobby_Order_Templet( "SELECT uid,SUM(cnt_win_farmer)+SUM(cnt_win_landlord) AS cnt,MAX(t_cnt_win) AS t FROM total_landlord_statistics GROUP BY uid ORDER BY cnt DESC,t ASC LIMIT 100" )
end

function CMD.lobby_Order_WinContinue( )
	return lobby_Order_Templet( "SELECT uid,SUM(cnt_win_win) AS cnt,MAX(t_max_cnt_win_win) AS t FROM total_landlord_statistics GROUP BY uid ORDER BY cnt DESC,t ASC LIMIT 100" )
end

function CMD.lobby_Order_HeroWin( id )
	return lobby_Order_Templet( string.format("SELECT uid,sum(cnt_win_landlord)+sum(cnt_win_farmer) AS cnt FROM hero_statistics WHERE hid=%d and game_mode<>2 GROUP BY uid ORDER BY cnt DESC,t_cnt ASC LIMIT 100", id))
end

function CMD.lobby_playbackinfs(uid,gameMode)

    local query=''
    if gameMode then
        query=string.format("select timestamp,room_id,content from landlord_detail_log where uid=%d and game_mode=%d order by timestamp DESC limit 10",uid,gameMode)
    else
        query=string.format("select UNIX_TIMESTAMP(timestamp) as timestamp,room_id,content,game_mode from landlord_detail_log where uid=%d order by timestamp DESC limit 10",uid)
    end

    local connect = getConnent()
	local database = connect.database 
    local res = database:query(query)  
	freeConnect(connect)
    if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return nil
	end

    return res
end

function CMD.lobby_GetUseGameAction(uid)
	local connect = getConnent()
	local database = connect.database 
	
	print("DC:lobbyGeUseGameAction():")
--                          101:game_cnt                          102:win_continue_max, 103:win cnt max, 104: boom cnt,105:spring cnt, 106: farmer spring cnt,107:max times,108:cnt win on one two,126:cnt master,127:cnt roomer
	local query="SELECT SUM(cnt_landlord)+SUM(cnt_farmer) AS cnt, MAX(max_cnt_win_win) AS win_max, SUM(cnt_win_landlord)+ SUM(cnt_win_farmer) AS win_cnt,SUM(cnt_boom) AS booms, SUM(cnt_spring) AS springs,SUM(cnt_farmer_spring) AS unsprings,MAX(max_times) AS times,SUM(cnt_win_one_two) AS win_otwo,SUM(cnt_master) AS masters,SUM(cnt_roomer) AS roomers FROM total_landlord_statistics WHERE uid="..uid.." GROUP BY uid;SELECT combination_id FROM hero_combination_log WHERE uid="..uid
	local res = database:query(query)  
	freeConnect(connect)
	if res.errno ~= nil then	
		log.error("sql erro:sql:%s\n,res:%s",query,debugEx:dump( res ))	
		return res.errno,nil
	end
	if  not res.mulitresultset or res.mulitresultset ~= true then	
		log.error("sql erro:sqld:%s\n,res:%s",query,debugEx:dump( res ))	
		return 10,nil
	end

	log.debug("sql debug:sql:%s\n,res:%s",query,debugEx:dump( res ))	

	local p2={}

	local game
	if res[1][1] then
		game=res[1][1]
	else
		game={}
		game.cnt=0
		game.win_cnt=0
		game.times=0
		game.win_otwo=0
		game.masters=0
		game.roomers=0
		game.cnt_farmer = 0
		game.cnt_landlord = 0
		game.win_max = 0
		game.win_farmer = 0
		game.win_landlord = 0
		game.springs = 0		
		game.unsprings = 0
		game.booms = 0
	end

	for _,v in ipairs(res[2]) do
		p2[v.combination_id]=1
	end

	return 0,game,p2
end
    
function CMD.lobby_getUseGameSimpleInf(uid,ranking_id)
	local query=nil
    local ranking_id=ranking_id or -1
    if ranking_id==1 or  ranking_id==-1 then
        query="SELECT SUM(cnt_landlord)+SUM(cnt_farmer) AS game_cnt, MAX(max_cnt_win_win) AS win_continue_cnt, SUM(cnt_win_landlord)+ SUM(cnt_win_farmer) AS win_cnt FROM total_landlord_statistics WHERE uid="..uid.." AND game_mode=3"
    else
        query="SELECT SUM(cnt_landlord)+SUM(cnt_farmer) AS game_cnt, MAX(max_cnt_win_win) AS win_continue_cnt, SUM(cnt_win_landlord)+ SUM(cnt_win_farmer) AS win_cnt FROM total_landlord_statistics_ranking WHERE uid="..uid.." AND game_mode=3".." and rank_id="..ranking_id
    end

	local err,res =	select_row_one_function(query)                     
	log.debug("sql debug:sql:%s\n,res:%s",query,debugEx:dump( res ))	
	if err ~= 0 then
		return  err
	end
	
	if next(res) ~= nil then
		return 0,res
	else
		return 0,{win_cnt=0,game_cnt=0,win_continue_cnt=0}
	end

end


function heartbeat_routine()
	while true do
		for k,v in ipairs(connent) do
			if not v.isQuerying then
				v.isQuerying=true
				local err,res =	select_row_one_function("SELECT NOW()",v,true) 
				v.isQuerying=false
				print("--------------------------------mysql dg-- k:",k,"t:",os.time())
			end
		end
				
		print("mysql dc-- t:",os.time())
		skynet.sleep(60000)	--(10*60*100)
	end
end

function CMD.start(input)
	local r=initConnect(input.cnt)
	if r then
		skynet.fork(heartbeat_routine)
	end
	return r
end
  
skynet.start(function()

    skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			log("DCGame Unknown command : [%s]", cmd)
			skynet.response()(false)
		end
	end)

    skynet.register "DCGame"
end)

