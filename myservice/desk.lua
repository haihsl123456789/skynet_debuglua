local skynet = require "skynet"
require "skynet.manager"

local log = require "log"
local config = require "cfgjson"
local math = math
local mytime = require "mytime"
local myrand = require "myrand"
local log = require "log"
local bullet = require "bullet"
local alghelper = require "alghelper"
local makefish = require "makefish"
local NetUtils = require "NetUtils"

local _this = {}
local _M = {}

-- type Desk struct {
-- 	DeskId int
-- 	ComMap map[string]Component
-- 	Rpc    *chanrpc.ChanRpc

-- 	IdFishMap    map[int]*Fish
-- 	IdPlayerMap  map[int]*Player
-- 	PosPlayerMap map[int]*Player
-- 	IdBulletMap  map[int]*Bullet
-- 	Status       int
-- 	SceneId      int

-- 	mainloopCancel *time.Ticker
-- 	savedbCancel   *time.Ticker

-- 	fishmakeid    int32 --for make
-- 	bulletmakeid  int32 --for make
-- 	stepBeginTime int
-- 	step          int
-- }


local	STEP_FREE         = 0
local	STEP_CHANGE_SCENE = 1
	-- -- STEP_TIDE

local	ERR_SEAT   = 255
local	C_MAX_SEAT = 4

local	ERR_FISH_NO_SEAT = 1000

local	C_CHANGESCENE_TIME = 2000

-- function _M:AddCom(comname string, com Component) {
-- 	self.ComMap[comname] = com
-- }
-- function _M:Com(comname string) Component {
-- 	return self.ComMap[comname]
-- }
-- function _M:ComMake() *MakeComponent {
-- 	return self.ComMap["make"].(*MakeComponent)
-- }

local function start_timer(interval, my_timer_task)  
	local isrun = true
	local function cancel()
		isrun = false
	end
    local function timer()  
        my_timer_task()  
		if isrun then
        	skynet.timeout(interval, timer)  
		end
    end  
    skynet.timeout(interval, timer)  

	return cancel
end

function NewDesk(deskid) --*Desk {
	local ret = {}
	ret.DeskId = deskid
	ret.ComMap = {} -- make(map[string]Component)
	ret.Rpc = {} -- chanrpc.NewChanRpc(1000, false)

	ret.IdFishMap = {} --make(map[int]*Fish)
	ret.IdPlayerMap = {} --make(map[int]*Player)
	ret.PosPlayerMap = {} --make(map[int]*Player)
	ret.IdBulletMap = {} -- make(map[int]*Bullet)

	ret.ComMake = makefish.NewMakeComponect(ret)
	--
	local freeFishIds = {21, 22, 23}
	local tideFishIds = {1, 2, 3}
	ret.ComMake:Init(freeFishIds, tideFishIds)

	ret.GotoStepFree()
	--
	ret.mainloopCancel = start_timer(25, ret.mainloop)
	ret.savedbCancel = start_timer(1, ret.savedb)
	-- go ret.msgloop()
	setmetatable(ret, {__index=_M})
	
	return ret
end

function _M:Destroy() 
	self.Rpc.Close()
end

function _M:MakeFishId() --int { --非零
	self.fishmakeid = self.fishmakeid + 1
	if self.fishmakeid == 0 then
		self.fishmakeid = 1
    end
	return math.tointeger(self.fishmakeid)
end

function _M:MakeBulletId() --int { --非零
	self.bulletmakeid = self.bulletmakeid + 1
	if self.bulletmakeid == 0 then
		self.bulletmakeid = 1
    end
	return math.tointeger(self.bulletmakeid)
end

function _M:msgloop() 
	while true do
		-- select {
		-- case <-self.mainloopCancel.C:
		-- 	self.mainloop()
		-- case dbt := <-self.savedbCancel.C:
		-- 	log.printdump("save db ticker:", dbt)
		-- 	self.savedb()
		-- case data := <-self.Rpc.Msg:
		-- 	self.Rpc.MsgHandle(data)
		-- }
	end
end

function _M:mainloop() 
	if self.step == STEP_FREE then
		local isEnd, fishes = self.ComMake:MakeFish(mytime.GetTime())
		self:AddFishes(fishes)
		if isEnd then
			self:GotoStepChangeScene()
        end
	elseif self.step == STEP_CHANGE_SCENE then
		if mytime.GetTime()-self.stepBeginTime > C_CHANGESCENE_TIME then
			self:GotoStepFree()
        end
	end

	--5秒清一次鱼
	self:UpdateFish()
	self:UpdateBullet()
	self:UpdatePlayer()
end

function _M:savedb() 
	log.Println("save db")
	-- for pid, player := range self.IdPlayerMap do
	-- 	win, lose, fee := player.Payout()
	-- 	go gamesavedb(pid, win, lose, fee, 10, 60)
    -- end
end

function _M:UpdateFish() 
	local curtime = mytime.GetTime()
	for id, fish in pairs( self.IdFishMap) do
		assert(id == fish.FishId)
		if fish:IsOutTime(curtime) then
			self:DelFish(id)
		else 
			fish:Update(curtime)
        end
	end
end

function _M:UpdateBullet() 
	local curtime = mytime.GetTime()
	local reason = "UpdateBullet:outtime:"
	for id, bullet in pairs(  self.IdBulletMap) do
		assert(id == bullet.BulletId)
		if bullet:IsOutTime(curtime) then
			self:DelBullet(id, reason)
		else 
			bullet:Update(curtime)
        end
	end
end

function _M:UpdatePlayer() 
	local curtime = mytime.GetTime()
	for id, player in pairs( self.IdPlayerMap) do
		assert(id == player.PlayerId)
		player:Update(curtime)
    end
end

function _M:GetIdlePostion() --int {
	for seat = 0, C_MAX_SEAT-1 do
		local p = self.PosPlayerMap[seat]
		if p == nil then
			return seat
        end
	end
	return ERR_SEAT
end

function _M:AddPlayer(player) --int {
	if self.IdPlayerMap[player.PlayerId] ~= nil then
		local p = self.IdPlayerMap[player.PlayerId]
		p.UpdateCon = player.Con
		return 0
	end

	local pos = self:GetIdlePostion()
	if pos == ERR_SEAT then
		log.Println("pos == ERR_SEAT@@@@@@@@@@@@@@@@@@", pos)
		return ERR_FISH_NO_SEAT
    end
	----------------init player--------------
	self.IdPlayerMap[player.PlayerId] = player
	self.PosPlayerMap[pos] = player

	player.SetPosition(pos)
	player.SetSitDownTime()

	-- TablePlayerInfoEvent msg;
	-- getInDeskFishPlayerMap(msg.fishPlayerInfo);
	-- BroadcastForSpecialProto(Proto_tablePlayerInfoPush, (void *)&msg, 1);
	return 0
end

function _M:DelPlayer(playerId ) --int {
	local pPlayer = self.IdPlayerMap[playerId]
	if pPlayer ~= nil then
		--清除玩家身上的子弹
		local IdBulletSet = pPlayer.IdBulletSet
		local reason = "delPlayer:"
		reason = reason .. string(playerId)
		for bulletid in pairs( IdBulletSet) do
			self:DelBullet(bulletid, reason)
        end

		self.PosPlayerMap[pPlayer.Position] = nil
		self.IdPlayerMap[pPlayer.PlayerId] = nil

		-- TablePlayerInfoEvent msg;
		-- getInDeskFishPlayerMap(msg.fishPlayerInfo);
		-- Broadcast(Proto_tablePlayerInfoPush, (void *)&msg);
	end
	return 0
end

function _M:AddBullet(pid , pBullet ) 
	local pPlayer = self.IdPlayerMap[pid]
	assert(pPlayer~=nil)
	pBullet.SetOwerInfo(pid, pPlayer.Position)

	pPlayer.InsertBullet(pBullet.BulletId)
	self.IdBulletMap[pBullet.BulletId] = pBullet
end

function _M:DelBullet(bulletid , reason ) 
	local bullet = self.IdBulletMap[bulletid]
	if bullet ~= nil then
		self.IdBulletMap[bulletid] = nil
		local playerid = bullet.OwerId
		local player = self.IdPlayerMap[playerid]
		if player ~= nil then
			player.RemoveBullet(bulletid)
			log.printdump("remove bullet", bulletid, reason)
        end
	end
end

function _M:AddFishes(fishes) 
	if fishes == nil or #fishes == 0 then
		return
    end

	local msg = {}
	msg.Fishes = {}

	for _, fish in pairs( fishes) do
		self:AddFish(fish)
		local data = {}
		fish:GetSendData(data)
		table.insert(msg.Fishes, data)
    end

	self:Broadcast(msg)
end

function _M:AddFish(fish ) 
	self.IdFishMap[fish.FishId] = fish
end

function _M:DelFish(fishid ) 
	-- fish, ok := self.IdFishMap[fishid]
	-- if ok {
	self.IdFishMap[fishid] = nil
	-- }
end

function _M:DelFishes(fishes ) 
	for _, fish in pairs(fishes) do
		self:DelFish(fish.FishId)
    end
end

function _M:GotoStepFree() 
	self.stepBeginTime = mytime.GetTime()
	self.step = STEP_FREE
	self.ComMake:BeginFree(self.stepBeginTime)
end

function _M:GotoStepChangeScene() 
	self.stepBeginTime = mytime.GetTime()
	self.step = STEP_CHANGE_SCENE

	self:ChangeFishEndLifeTime(self.stepBeginTime + C_CHANGESCENE_TIME)

	self.SceneId = myrand.Intn(0, 5)

	local  msg = {} -- protodata.ChangeScenePush
	msg.Sceneid = (self.SceneId)
	self:Broadcast(msg)
end

function _M:ChangeFishEndLifeTime(endTime ) 
	for _, fish in pairs( self.IdFishMap) do
		fish:ChangeEndLifeTime(endTime)
    end
end

function _M:Broadcast(pMsg ) 
	for _, player in pairs( self.IdPlayerMap) do
		player:SendMsg(pMsg)
    end
end

-- func RPC_Fire(this interface{}, pid interface{}, req interface{}) 
-- 	self.(*Desk).Fire(pid.(int), req.(*protodata.FireReq))
-- end

function _M:Fire(pid , req ) 
	local player = self.IdPlayerMap[pid]
	if player == nil then
		return
    end
	if !player:EnoughGold((req.BulletTimes)) then
		return
    end
	player:SubGold((req.BulletTimes))
	local bullet = bullet.NewBullet(self:MakeBulletId(), (req.BulletTimes), (req.TargetFishId),
		{(req.Direction.X), (req.Direction.Y)}, mytime.GetTime(), 1000*15)
	bullet:SetOwerInfo(pid, player.Position)
	self:AddBullet(pid, bullet)

	local msg = {} -- protodata.FirePush
	msg.Bullet = {} -- new(protodata.Bullet)
	bullet.GetSendData(msg.Bullet)
	self:Broadcast(msg)
end

-- func RPC_CollideFish(this interface{}, pid interface{}, req interface{}) {
-- 	self.(*Desk).CollideFish(pid.(int), req.(*protodata.CollideFishReq))
-- }
function _M:CollideFish(pid , req ) 
	local player = self.IdPlayerMap[pid]
	if player == nil then
		log.Println("collide fish: no player")
		return
    end
	if #req.AreaFishIds == 0 then
		log.Println("collide fish: req.AreaFishIds) == 0")
		return
    end
	local curTime = mytime.GetTime()
	local bullet = self.IdBulletMap[(req.BulletId)]
	if bullet == nil or bullet:IsOutTime(curTime) then
		log.Println("collide fish: no bullet || bullet.IsOutTime(curTime)")
		return
    end
	local fishid = (req.AreaFishIds[0])
	local fish = self.IdFishMap[fishid]
	if fish == nil or !fish:IsInLifeTime(curTime) then
		log.Println("collide fish: no fish || !fish.IsInLifeTime(curTime)")
		return
    end
	if alghelper:AlgKillFish(bullet.BulletTimes, fish.FishTimes) then
		local getgold = fish.FishTimes * bullet.BulletTimes
		player:AddGold(getgold)
		self:DelFish(fishid)

		local  msg = {} -- protodata.CollideFishPush
		msg.BulletId = req.BulletId
		msg.CollideFishId = (fishid)
		msg.CatchFishes = {} -- make([]*protodata.CatchFishInfo, 0, 1)
		local catchinfo = {} -- new(protodata.CatchFishInfo)
		catchinfo.FishId = (fishid)
		catchinfo.FishTimes = (fish.FishTimes)
		catchinfo.GetGold = (getgold)
		table.insert(msg.CatchFishes, catchinfo)
		self:Broadcast(msg)
    end

	self:DelBullet((req.BulletId), "collide")
end

-- local _this = {}

local _this = {}
function _this.init(deskid)
	_this = NewDesk(deskid)
end


skynet.start(function()
	NetUtils:register()

    skynet.dispatch("lua", function(_,_, command, ...)
		local f = _this[command]
		if f then
			skynet.ret(skynet.pack(f(_this, ...)))
		else
			log("desk Unknown command : [%s]", command)
			skynet.response()(false)
		end
	end)

    -- skynet.register "playermgr"
end)