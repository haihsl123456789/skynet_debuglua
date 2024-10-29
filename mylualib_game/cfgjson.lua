local log = require "log"
local lfs = require("lfs")
local cjson = require("cjson")
local string = string

cjson.encode_empty_table_as_array(true)  --???

-- type (
-- 	SFishMapping struct {
-- 		EditId int
-- 		CodeId int
-- 	}
-- 	SFishConfig struct {
-- 		Id           int
-- 		TimesMin     int
-- 		TimesMax     int
-- 		BombTimesMin int
-- 		BombTimesMax int
-- 		Type         int
-- 		SimilarType  int
-- 	}

-- 	FishConfig struct {
-- 		Id      int
-- 		FishMap map[int]*SFishConfig --key: fishTypeId
-- 		FishIds []int
-- 	}

local function NewFishConfig()
    return {
        Id = 0,
        FishMap = {},
        FishIds = {}
    }
end

-- 	STrackConfig struct {
-- 		X float64
-- 		Y float64
-- 		A float64
-- 	}

-- 	TrackConfig struct {
-- 		PointCnt int
-- 		Time     int
-- 		Tracks   []*STrackConfig
-- 	}
local function NewTrackConfig()
    return {
        PointCnt = 0,
        Time = 0,
        Tracks = {}
    }
end
-- 	STideConfig struct {
-- 		FishTypeId   int
-- 		TrackId      int
-- 		XOffset      float64
-- 		YOffset      float64
-- 		BeginTime    int
-- 		IntervalTime int
-- 		MakeCnt      int
-- 	}

-- 	TideConfig struct {
-- 		Id    int
-- 		Time  int
-- 		Tides []*STideConfig
-- 	}

local function NewTideConfig()
    return {
        Id = 0,
        Time = 0,
        Tides = {}
    }
end

-- 	SFreeConfig struct {
-- 		FishTypeId   int
-- 		TrackIds     []int
-- 		XOffsets     []int
-- 		YOffsets     []int
-- 		MakeCntMin   int
-- 		MakeCntMax   int
-- 		BeginTime    int
-- 		IntervalTime int
-- 	}
local function NewSFreeConfig()
    return {
        FishTypeId = 0,
        TrackIds = {},
        XOffsets = {},
        YOffsets = {},
        MakeCntMin = 0,
        Time = 0,
        MakeCntMax = 0,
        BeginTime = 0,
        IntervalTime = 0,
    }
end
-- 	FreeConfig struct {
-- 		Id    int
-- 		Time  int
-- 		Frees []*SFreeConfig
-- 	}
local function NewFreeConfig()
    return {
        Id = 0,
        Time = 0,
        Frees = {}
    }
end

-- 	JsonConfig struct {
-- 		Fish        map[int]*FishConfig
-- 		Track       map[int]*TrackConfig
-- 		Tide        map[int]*TideConfig
-- 		Free        map[int]*FreeConfig
-- 		FishMapping map[int]int
-- 	}

-- 	fun_jsonparse func(js []byte, num int)
-- )

local jsoncfg = {}  --JsonConfig

function jsoncfg.GetFish() --*FishConfig         
    return jsoncfg.Fish[1] 
end    

function jsoncfg.GetTrack(id ) --*TrackConfig 
    return jsoncfg.Track[id] 
end

function jsoncfg.GetTide(id ) --*TideConfig   
    return jsoncfg.Tide[id] 
end

function jsoncfg.GetFree(id ) --*FreeConfig   
    return jsoncfg.Free[id] 
end

function jsoncfg.GetTrackTime(id ) --int      
    return jsoncfg.GetTrack(id).Time 
end

function jsoncfg.GetFishMapping(editid ) --int 
	local ret = jsoncfg.FishMapping[editid]
	if ret == nil then
		log.Fatalln("GetFishMapping :", editid)
    end
	return ret
end

--------------------------------------------------------------------------------------------

local funMap = {}  --map[string]fun_jsonparse



-- local filename = "Title59.Json"  
local function ParseJsonFileName(filename)
    -- filename = string.lower(filename)
    -- 使用模式匹配解析字符串  
    local title, number, extension = string.match(filename, "^(%a+)(%d+)%.(%a+)$")  

    -- log.Println("Title:", title)       -- 输出: Title: title  
    -- log.Println("Number:", number)     -- 输出: Number: 59  
    -- log.Println("Extension:", extension) -- 输出: Extension: json  
	-- extension = string.lower(extension)

    if extension == "json" and title~=nil and number~=nil and tonumber(number) then
        return title, tonumber(number), true
    end
    return nil, nil, false
end

local function readfile(filename)
    local f = assert(io.open(filename), "Can't open " .. filename)
    local t = f:read "a"
    f:close()
    return t, true
end

local function parseDir(path ) 
	for file in lfs.dir(path) do
        if file ~= "." and file ~= ".." then
            local filepath = path .. "/" .. file
            local attr = lfs.attributes(filepath)
            if attr.mode == "directory" then
                log.Println("dir: ", file)
                parseDir(filepath)
            elseif attr.mode == "file" then
                log.Println("file: ", file)
                local filetype, num, ok = ParseJsonFileName(file)
                if ok then
                    local parseFun = funMap[filetype]
                    if parseFun == nil then
                        log.Println("no find File type fun:", filetype, file)
                        goto continue
                    end
                    local data, ok = readfile(filepath)
                    if not ok then
                        log.Println("File reading error:",  filepath)
                        goto continue
                    end
                    parseFun(data, num)
                end
            end
        end

        ::continue::
    end
end

local function fishParse(js , num ) 
	-- local data = {} -- make([]SFishConfig, 0)
	-- json.Unmarshal(js, &data)
    local ok, data = pcall(cjson.decode, js)
    if not ok then
        log.Println("fishParse decode error", js, data)
        return
    end
    
	local cfg = NewFishConfig()
	-- cfg.FishMap = make(map[int]*SFishConfig)
	-- cfg.FishIds = make([]int, 0)
	for _, inf in ipairs(data) do
		cfg.FishMap[inf.id] = inf
        table.insert(cfg.FishIds, inf.id)
    end
	table.sort(cfg.FishIds)
	jsoncfg.Fish[num] = cfg
	-- log.Println(cfg)
end

local function fishMappingParse(js , num ) 
	-- data := make([]SFishMapping, 0)
	-- json.Unmarshal(js, &data)
    local ok, data = pcall(cjson.decode, js)
    if not ok then
        log.Println("fishMappingParse decode error", js, data)
        return
    end    
	for _, inf in ipairs(data) do
		jsoncfg.FishMapping[inf.editId] = inf.codeId
    end
	-- log.Println(cfg)
end

local function trackParse(js , num ) 
	-- data := make([]STrackConfig, 0)
	-- json.Unmarshal(js, &data)
    local ok, data = pcall(cjson.decode, js)
    if not ok then
        log.Println("trackParse decode error", js, data)
        return
    end        
	local cfg = NewTrackConfig()
	cfg.PointCnt = #data
	cfg.Time = cfg.PointCnt * 33
	cfg.Tracks = {} --make([]*STrackConfig, 0)
	for _, inf in ipairs(data) do
		-- cfg.Tracks = append(cfg.Tracks, &data[i])
        table.insert(cfg.Tracks, inf)
    end
	jsoncfg.Track[num] = cfg
	-- log.Println(cfg)
end

local function tideParse(js, num ) 
	-- [ID,"名称",总时长],
	-- [鱼1,路径,X偏移,Y偏移,起始时间,生成间隔,生成总数],
	-- local data interface{}
	-- json.Unmarshal(js, &data)
    local ok, data = pcall(cjson.decode, js)
    if not ok then
        log.Println("tideParse decode error", js, data)
        return
    end   
	
	local cfg = NewTideConfig()
	cfg.Id = num
	-- cfg.Tides = make([]*STideConfig, 0)

	-- array := data.([]interface{})
	-- line1 := array[0].([]interface{})
	-- cfg.Time = int(line1[2].(float64) * 1000)

	local array = data
	local line1 =  data[1]
	cfg.Time = math.floor( line1[3]*1000)

	for i, line in ipairs(data) do
		if i == 1 then
			goto continue
		end
		-- line := array[i].([]interface{})
		local tide = {} --STideConfig
		tide.FishTypeId = math.floor(line[1])
		tide.TrackId = math.floor(line[2])
		tide.XOffset = math.floor(line[3])
		tide.YOffset = math.floor(line[4])
		tide.BeginTime = math.floor(line[5])
		tide.IntervalTime = math.floor(line[6])
		tide.MakeCnt = math.floor(line[7])

		-- cfg.Tides = append(cfg.Tides, &tide)
		table.insert(cfg.Tides, tide)

		::continue::
    end

	table.sort((cfg.Tides), function(a,b)
		return a.BeginTime < b.BeginTime
	end)

	jsoncfg.Tide[num] = cfg
end

local function freeParse(js , num) 
	-- local data interface{}
	-- json.Unmarshal(js, &data)

    local ok, data = pcall(cjson.decode, js)
    if not ok then
        log.Println("freeParse decode error", js, data)
        return
    end   	

	local cfg = NewFreeConfig()
	cfg.Id = num
	-- cfg.Frees = make([]*SFreeConfig, 0)

	-- 	[ID,"名称",总时长],
	-- [鱼1,[路径1,路径2,...],[X偏移最小值,X偏移最大值],[Y偏移最小值,Y偏移最大值],[生成数最小值,生成数最大值],起始时间,生成间隔],

	-- array := data.([]interface{})
	-- line1 := array[0].([]interface{})
	-- cfg.Time = int(line1[2].(float64) * 1000)

	local line1 =  data[1]
	cfg.Time = math.floor(line1[3]*1000)

	for i, line in ipairs(data) do
		if i == 1 then
			goto continue
		end
		-- line := array[i].([]interface{})
		local free = NewSFreeConfig()
		free.FishTypeId = math.floor(line[1])

		local TrackIds = line[2]
		for _, inf in ipairs(TrackIds) do
			table.insert(free.TrackIds, math.floor(inf))
		end

		local XOffsets = line[3]
		for _, inf in ipairs(XOffsets) do
			table.insert(free.XOffsets, math.floor(inf))
		end

		local YOffsets = line[4]
		for _, inf in ipairs(YOffsets) do
			table.insert(free.YOffsets, math.floor(inf))
		end		

		local MakeCnt = line[5]
		free.MakeCntMin =  math.floor(MakeCnt[1])
		if #MakeCnt == 2 then
			free.MakeCntMax = math.floor(MakeCnt[2])
		else
			free.MakeCntMax = free.MakeCntMin
		end

		free.BeginTime = math.floor(line[6])
		free.IntervalTime = math.floor(line[7])

		table.insert(cfg.Frees, free)

		::continue::
	end

	table.sort(cfg.Frees, function(a,b)
			return a.BeginTime < b.BeginTime
	end)

	jsoncfg.Free[num] = cfg
	-- log.Println(cfg)
end



function jsoncfg.Initcfgjson() 
	jsoncfg.Fish = {}
	jsoncfg.Track = {}
	jsoncfg.Tide = {}
	jsoncfg.Free = {}
	jsoncfg.FishMapping = {}

	funMap["fish"] = fishParse
	funMap["fishMapping"] = fishMappingParse
	funMap["BYPath"] = trackParse
	funMap["Free"] = freeParse
	funMap["Tide"] = tideParse

	parseDir("./jsondata")
	log.Println("parse json ok!!")
	-- log.printdump(jsoncfg, "jsoncfg:")
end


return jsoncfg