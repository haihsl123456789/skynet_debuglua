local log = require "log"
local config = require "cfgjson"
local math = math
local mytime = require "mytime"

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

-- 	mainloopticker *time.Ticker
-- 	savedbticker   *time.Ticker

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

function NewDesk(deskid ) --*Desk {
	local ret = {

    }
	ret.DeskId = deskid
	ret.ComMap = {} -- make(map[string]Component)
	ret.Rpc = {} -- chanrpc.NewChanRpc(1000, false)

	ret.IdFishMap = {} --make(map[int]*Fish)
	ret.IdPlayerMap = {} --make(map[int]*Player)
	ret.PosPlayerMap = {} --make(map[int]*Player)
	ret.IdBulletMap = {} -- make(map[int]*Bullet)

	ret.AddCom(NewComponent("make", this))
	--
	local freeFishIds = {21, 22, 23}
	local tideFishIds = {1, 2, 3}
	ret.ComMake().Init(freeFishIds, tideFishIds)

	ret.GotoStepFree()
	--
	ret.mainloopticker = time.NewTicker(time.Millisecond * 250)
	ret.savedbticker = time.NewTicker(time.Second * 10)
	-- go ret.msgloop()

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
		-- case <-self.mainloopticker.C:
		-- 	self.mainloop()
		-- case dbt := <-self.savedbticker.C:
		-- 	fmt.Println("save db ticker:", dbt)
		-- 	self.savedb()
		-- case data := <-self.Rpc.Msg:
		-- 	self.Rpc.MsgHandle(data)
		-- }
	end
end

function _M:mainloop() 
	if self.step == STEP_FREE then
		local isEnd, fishes = self.ComMake().MakeFish(mytime.GetTime())
		self.AddFishes(fishes)
		if isEnd then
			self.GotoStepChangeScene()
        end
	elseif self.step == STEP_CHANGE_SCENE then
		if mytime.GetTime()-self.stepBeginTime > C_CHANGESCENE_TIME then
			self.GotoStepFree()
        end
	end

	--5秒清一次鱼
	self.UpdateFish()
	self.UpdateBullet()
	self.UpdatePlayer()
end

function _M:savedb() 
	log.Println("save db")
	for pid, player := range self.IdPlayerMap do
		win, lose, fee := player.Payout()
		go gamesavedb(pid, win, lose, fee, 10, 60)
    end
end

function _M:UpdateFish() 
	curtime := mytime.GetTime()
	for id, fish := range self.IdFishMap do
		utils.Assert(id == fish.FishId)
		if fish.IsOutTime(curtime) then
			self.DelFish(id)
		else 
			fish.Update(curtime)
        end
	end
end

function _M:UpdateBullet() 
	curtime := mytime.GetTime()
	reason := "UpdateBullet:outtime:"
	for id, bullet := range self.IdBulletMap do
		utils.Assert(id == bullet.BulletId)
		if bullet.IsOutTime(curtime) then
			self.DelBullet(id, reason)
		else 
			bullet.Update(curtime)
        end
	end
end

function _M:UpdatePlayer() 
	curtime := mytime.GetTime()
	for id, player := range self.IdPlayerMap do
		utils.Assert(id == player.PlayerId)
		player.Update(curtime)
    end
end

function _M:GetIdlePostion() --int {
	for seat := 0; seat < C_MAX_SEAT; seat++ do
		_, ok := self.PosPlayerMap[seat]
		if !ok then
			return seat
        end
	end
	return ERR_SEAT
end

function _M:AddPlayer(player *Player) --int {
	pos := self.GetIdlePostion()
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

function _M:DelPlayer(playerId int) --int {
	pPlayer, ok := self.IdPlayerMap[playerId]
	if ok then
		--清除玩家身上的子弹
		IdBulletSet := pPlayer.IdBulletSet
		reason := "delPlayer:"
		reason += string(playerId)
		for bulletid, _ := range IdBulletSet do
			self.DelBullet(bulletid, reason)
        end

		delete(self.PosPlayerMap, pPlayer.Position)
		delete(self.IdPlayerMap, pPlayer.PlayerId)

		-- TablePlayerInfoEvent msg;
		-- getInDeskFishPlayerMap(msg.fishPlayerInfo);
		-- Broadcast(Proto_tablePlayerInfoPush, (void *)&msg);
	end
	return 0
end

function _M:AddBullet(pid int, pBullet *Bullet) 
	pPlayer, ok := self.IdPlayerMap[pid]
	utils.Assert(ok)
	pBullet.SetOwerInfo(pid, pPlayer.Position)

	pPlayer.InsertBullet(pBullet.BulletId)
	self.IdBulletMap[pBullet.BulletId] = pBullet
end

function _M:DelBullet(bulletid int, reason string) 
	bullet, ok := self.IdBulletMap[bulletid]
	if ok then
		delete(self.IdBulletMap, bulletid)
		playerid := bullet.OwerId
		player, ok := self.IdPlayerMap[playerid]
		if ok then
			player.RemoveBullet(bulletid)
			fmt.Println("remove bullet", bulletid, reason)
        end
	end
end

function _M:AddFishes(fishes []*Fish) 
	if len(fishes) == 0 then
		return
    end

	var msg protodata.FishesPush
	msg.Fishes = make([]*protodata.Fish, 0, len(fishes))

	for _, fish := range fishes do
		self.AddFish(fish)
		data := new(protodata.Fish)
		fish.GetSendData(data)
		msg.Fishes = append(msg.Fishes, data)
    end

	self.Broadcast(&msg)
end

function _M:AddFish(fish *Fish) 
	self.IdFishMap[fish.FishId] = fish
end

function _M:DelFish(fishid int) 
	-- fish, ok := self.IdFishMap[fishid]
	-- if ok {
	delete(self.IdFishMap, fishid)
	-- }
end

function _M:DelFishes(fishes []*Fish) 
	for _, fish := range fishes do
		self.DelFish(fish.FishId)
    end
end

function _M:GotoStepFree() 
	self.stepBeginTime = mytime.GetTime()
	self.step = STEP_FREE
	self.ComMake().BeginFree(self.stepBeginTime)
end

function _M:GotoStepChangeScene() 
	self.stepBeginTime = mytime.GetTime()
	self.step = STEP_CHANGE_SCENE

	self.ChangeFishEndLifeTime(self.stepBeginTime + C_CHANGESCENE_TIME)

	self.SceneId = myrand.Intn(0, 5)

	var msg protodata.ChangeScenePush
	msg.Sceneid = int32(self.SceneId)
	self.Broadcast(&msg)
end

function _M:ChangeFishEndLifeTime(endTime int) 
	for _, fish := range self.IdFishMap do
		fish.ChangeEndLifeTime(endTime)
    end
end

function _M:Broadcast(pMsg interface{}) 
	for _, player := range self.IdPlayerMap do
		player.SendMsg(pMsg)
    end
end

-- func RPC_Fire(this interface{}, pid interface{}, req interface{}) 
-- 	self.(*Desk).Fire(pid.(int), req.(*protodata.FireReq))
-- end

function _M:Fire(pid int, req *protodata.FireReq) 
	player, ok := self.IdPlayerMap[pid]
	if !ok then
		return
    end
	if !player.EnoughGold(int(req.BulletTimes)) then
		return
    end
	player.SubGold(int(req.BulletTimes))
	bullet := NewBullet(self.MakeBulletId(), int(req.BulletTimes), int(req.TargetFishId),
		Point{float64(req.Direction.X), float64(req.Direction.Y)}, mytime.GetTime(), 1000*15)
	bullet.SetOwerInfo(pid, player.Position)
	self.AddBullet(pid, bullet)

	var msg protodata.FirePush
	msg.Bullet = new(protodata.Bullet)
	bullet.GetSendData(msg.Bullet)
	self.Broadcast(&msg)
end

-- func RPC_CollideFish(this interface{}, pid interface{}, req interface{}) {
-- 	self.(*Desk).CollideFish(pid.(int), req.(*protodata.CollideFishReq))
-- }
function _M:CollideFish(pid int, req *protodata.CollideFishReq) 
	player, ok := self.IdPlayerMap[pid]
	if !ok then
		log.Println("collide fish: no player")
		return
    end
	if len(req.AreaFishIds) == 0 then
		log.Println("collide fish: req.AreaFishIds) == 0")
		return
    end
	curTime := mytime.GetTime()
	bullet, ok := self.IdBulletMap[int(req.BulletId)]
	if !ok || bullet.IsOutTime(curTime) then
		log.Println("collide fish: no bullet || bullet.IsOutTime(curTime)", ok)
		return
    end
	fishid := int(req.AreaFishIds[0])
	fish, ok := self.IdFishMap[fishid]
	if !ok || !fish.IsInLifeTime(curTime) then
		log.Println("collide fish: no fish || !fish.IsInLifeTime(curTime)", ok)
		return
    end
	if alghelper.AlgKillFish(bullet.BulletTimes, fish.FishTimes) then
		getgold := fish.FishTimes * bullet.BulletTimes
		player.AddGold(getgold)
		self.DelFish(fishid)

		var msg protodata.CollideFishPush
		msg.BulletId = req.BulletId
		msg.CollideFishId = int32(fishid)
		msg.CatchFishes = make([]*protodata.CatchFishInfo, 0, 1)
		catchinfo := new(protodata.CatchFishInfo)
		catchinfo.FishId = int32(fishid)
		catchinfo.FishTimes = int32(fish.FishTimes)
		catchinfo.GetGold = int64(getgold)
		msg.CatchFishes = append(msg.CatchFishes, catchinfo)
		self.Broadcast(&msg)
    end

	self.DelBullet(int(req.BulletId), "collide")
end
