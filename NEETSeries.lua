--[[ NEET Series Version 0.28
	_____   ___________________________   ________           _____             
	___  | / /__  ____/__  ____/__  __/   __  ___/______________(_)____________
	__   |/ /__  __/  __  __/  __  /      _____ \_  _ \_  ___/_  /_  _ \_  ___/
	_  /|  / _  /___  _  /___  _  /       ____/ //  __/  /   _  / /  __/(__  ) 
	/_/ |_/  /_____/  /_____/  /_/        /____/ \___//_/    /_/  \___//____/  

---------------------------------------]]
local NEETSeries_Version = 0.28
local function NEETSeries_Print(text) PrintChat(string.format("<font color=\"#4169E1\"><b>[NEET Series]:</b></font><font color=\"#FFFFFF\"> %s</font>", tostring(text))) end

if not FileExist(COMMON_PATH.."MixLib.lua") then
	NEETSeries_Print("MixLib.lua not found. Please wait...")
	DownloadFileAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/MixLib.lua", COMMON_PATH.."MixLib.lua", function() NEETSeries_Print("Downloaded MixLib.lua, please 2x F6!") end)
	return
else require('MixLib') end

if not FileExist(COMMON_PATH.."OpenPredict.lua") or not FileExist(COMMON_PATH.."ChallengerCommon.lua") or not FileExist(COMMON_PATH.."DamageLib.lua") or not FileExist(COMMON_PATH.."Analytics.lua") then return end
if not ChallengerCommonLoaded then require("ChallengerCommon") end
if not Analytics then require("Analytics") end

local SupTbl = {"Xerath", "KogMaw", "Annie", "Kalista"}
local Supported = Set(SupTbl)

local NS_Menu = MenuConfig("NEETSeries", "[NEET Series]: Menu")
	NS_Menu:Boolean("Tracker", "Load Tracker", true, function(v) NEETSeries_Print("Please 2x F6 to "..(v and "Load" or "UnLoad").." NS_Awa") end)
	if Supported[myHero.charName] then NS_Menu:Boolean("Plugin", "Load NS_"..myHero.charName, true, function(v) NEETSeries_Print("Please 2x F6 to "..(v == true and "Load" or "UnLoad").." NS_"..myHero.charName) end)
	else NS_Menu:Info("nope", "Not supported for "..myHero.charName) end
	NS_Menu:Info("ifo", "Current Orbwalker: "..Mix.OW)
	NS_Menu:Info("ifo2", "Script Version: "..NEETSeries_Version)
	NS_Menu:Info("ifo3", "LoL Version: "..GetGameVersion():sub(1, 13))

class "LoadEnemies"
function LoadEnemies:__init()
	self.Count = 0;
	self.List = {nil, nil, nil, nil, nil};
	OnObjectLoad(function(Object)
		if Object.team ~= myHero.team and Object.isHero then
			self.Count = self.Count + 1;
			self.List[self.Count] = Object;
		end
	end)
	table.sort(self.List, function(a, b) return a.charName < b.charName end)
end

class "__MinionManager"
function __MinionManager:__init(range1, range2)
	self.range1 = range1*range1
	self.range2 = range2*range2
	self.minion = {}
	self.mob = {}
	self.tminion = {}
	self.tmob = {}
	self.mmob = nil
	OnObjectLoad(function(obj) self:CreateObj(obj) end)
	OnCreateObj(function(obj) self:CreateObj(obj) end)
	OnDeleteObj(function(obj) self:DeleteObj(obj) end)
end

function __MinionManager:CreateObj(obj)
	if GetObjectType(obj) ~= Obj_AI_Minion or GetObjectBaseName(obj):find("Plant") or GetTeam(obj) == MINION_ALLY then return end
	if GetObjectName(obj):find("Minion") and GetTeam(obj) ~= 300 then
		self.minion[#self.minion + 1] = obj
		return
	end

	if GetTeam(obj) == 300 then
		self.mob[#self.mob + 1] = obj
	end	
end

function __MinionManager:DeleteObj(obj)
	if GetObjectType(obj) ~= Obj_AI_Minion or GetObjectBaseName(obj):find("Plant") or GetTeam(obj) == MINION_ALLY then return end
	if GetObjectName(obj):find("Minion") and GetTeam(obj) ~= 300 then
		for i = 1, #self.minion do
			if self.minion[i] == obj then
				table.remove(self.minion, i)
				return
			end
		end
	end

	if GetTeam(obj) == 300 then
		for i = 1, #self.mob do
			if self.mob[i] == obj then
				table.remove(self.mob, i)
				return
			end
		end
	end
end

function __MinionManager:Update()
	self.tminion = {}
	for i = 1, #self.minion, 1 do
		local minion = self.minion[i]
		if GetDistanceSqr(minion) <= self.range1 and IsObjectAlive(minion) and IsTargetable(minion) and not IsImmune(minion, myHero) and GetTeam(minion) == MINION_ENEMY then
			
			self.tminion[#self.tminion + 1] = minion
		end
	end

	self.tmob = {}
	local BiggestMob = nil
	for i = 1, #self.mob, 1 do
		local mob = self.mob[i]
		if GetDistanceSqr(mob) <= self.range2 and IsObjectAlive(mob) and IsTargetable(mob) and not IsImmune(mob, myHero) and GetTeam(mob) == 300 then
			self.tmob[#self.tmob + 1] = mob
			if not BiggestMob or GetMaxHP(BiggestMob) < GetMaxHP(mob) then BiggestMob = mob end
		end
	end
	self.mmob = nil
end

local pred = {"OpenPredict", "GPrediction", "GoSPrediction"}
function LoadPredMenu(menu, v)
	menu:DropDown("cpred", "Choose Prediction:", v or 1, pred, function(val) NEETSeries_Print("2x F6 to ally using "..pred[val]) end)
	menu:Info("currentPred", "Current Prediction: "..pred[menu.cpred:Value()])
	if menu.cpred:Value() == 2 and FileExist(COMMON_PATH.."GPrediction.lua") then require("GPrediction") end
end

local OPM = {
	["linear"] = GetLinearAOEPrediction,
	["circular"] = GetCircularAOEPrediction,
	["cone"] = GetConicAOEPrediction
}
local checkHC = {
	{0.1, 0.25, 0.4, 0.9},
	{3, 3, 3, 3},
	{1, 1, 1, 1}
}
class "AddSpell"
function AddSpell:__init(spellData, menu, v, h)
	menu:DropDown("chc", "Choose Hit-chance", h or 3, {"Low", "Normal", "High", "Very High"}, function(v) self.hc = checkHC[self.method][v] end)
	if v == 1 then spellData.type = "linear" end
	if v == 2 then spellData.type = "line" end
	spellData.radius = spellData.width * 0.5
	spellData.col = {"minion", "champion"}
	self.method = v
	self.data = spellData
	self.hc = checkHC[self.method][menu.chc:Value()]
end

local function CastTo(pos, slot, css2)
	if not css2 then
		CastSkillShot(slot, pos)
	elseif GetDistanceSqr(pos) <= css2*css2 then
		CastSkillShot2(slot, pos)
	end
end

function AddSpell:Cast(target, CSS2)
	if self.method == 1 then
		if self.data.colNum > 0 then
			local Pred = GetPrediction(target, self.data)
			if not Pred:mCollision(self.data.colNum) and Pred.hitChance >= self.hc then
				CastTo(Pred.castPos, self.data.slot, CSS2)
			end
		else
			local Pred = OPM[self.data.type](target, self.data)
			if Pred.hitChance >= self.hc then
				CastTo(Pred.castPos, self.data.slot, CSS2)
			end
		end
		return
	end
	if self.method == 2 then
		local Pred = gPred:GetPrediction(target, myHero, self.data, self.data.colNum == 0, self.data.colNum > 0)
		if Pred.HitChance >= self.hc then
			CastTo(Pred.CastPosition, self.data.slot, CSS2)
		end
		return
	end
	if self.method == 3 then
		local Pred = GetPredictionForPlayer(myHero, target, target.ms, self.data.speed, self.data.delay, self.data.range, self.data.width, self.data.colNum > 0, true)
		if Pred.HitChance >= self.hc then
			CastTo(Pred.PredPos, self.data.slot, CSS2)
		end
	end
end

if not FileExist(COMMON_PATH.."NS_Awa.lua") then
	NEETSeries_Print("NS_Awa.lua not found. Please wait...")
	DownloadFileAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NS_Awa.lua", COMMON_PATH.."NS_Awa.lua", function() NEETSeries_Print("Downloaded NS_Awa.lua, please 2x F6!") end)
	return
end

do
	if NS_Menu.Tracker:Value() and FileExist(COMMON_PATH.."NS_Awa.lua") then
		NS_Menu:Menu("NSAwa", "NS Awaraness")
		require("NS_Awa")
		NS_Awaraness(NS_Menu.NSAwa)
	end
end

function NS_updateP(v, Ver)
	if v <= #SupTbl and not FileExist(COMMON_PATH.."NS_"..SupTbl[v]..".lua") then NS_updateP(v + 1, Ver) return end
	if v > #SupTbl then NEETSeries_Print("Updated to version "..Ver..". Please F6 x2 to reload.") return end
	DownloadFileAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NS_"..SupTbl[v]..".lua", COMMON_PATH.."NS_"..SupTbl[v]..".lua", function() NS_updateP(v + 1, Ver) return end) return
end

OnLoad(function()
	GetWebResultAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NEETSeries.version", function(OnlineVer)
		if tonumber(OnlineVer) > NEETSeries_Version then
			NEETSeries_Print("New Version found (v"..OnlineVer.."). Please wait...")
			DownloadFileAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NEETSeries.lua", SCRIPT_PATH.."NEETSeries.lua", function() NS_updateP(1, tostring(OnlineVer)) return end) return
		else
			if Supported[myHero.charName] then
				PrintChat(string.format("<font color=\"#4169E1\"><b>[NEET Series]:</b></font><font color=\"#FFFFFF\"><i> Successfully Loaded</i> (v%s) | Good Luck</font> <font color=\"#C6E2FF\"><u>%s</u></font>", NEETSeries_Version, GetUser())) return
			end
		end
	end)
end)

do
	if not Supported[myHero.charName] then NEETSeries_Print("Not Supported For "..myHero.charName) return end
	if not FileExist(COMMON_PATH.."NS_"..myHero.charName..".lua") then
		NEETSeries_Print("Downloading NS_"..myHero.charName..".lua. Please wait...")
		DelayAction(function() DownloadFileAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NS_"..myHero.charName..".lua", COMMON_PATH.."NS_"..myHero.charName..".lua", function() NEETSeries_Print("Downloaded plugin NS_"..myHero.charName..".lua, please 2x F6!") return end) end, 0.3)
		return
	elseif NS_Menu.Plugin:Value() then
		require("NS_"..myHero.charName)
		Analytics("NEETSeries", "Ryzuki", true)
	end
end

--[[ -------------> Change log <-------------
		{ Version 0.15 }
			- Deleted support Annie, Kog'Maw, Katarina.
			- Improve somethings
			- Added escape for Xerath

		{ Version 0.16 }
			- Fixed somethings

		{ Version 0.17 }
			- Added Annie, Kog'Maw

		{ Version 0.18 }
			- Added Katarina

		{ Version 0.19 }
			- Added Tracker (cooldown tracker only)

		{ Version 0.2 }
			- Fixed somethings

		{ Version 0.21 }
			- Fixed somethings, Added cd tracker for allies

		{ Version 0.22 }
			- Fixed Kog'Maw RDmg, Added RecallTracker and MinimapTrack

		{ Version 0.23 - 0.24 }
			- Fixed somethings

		{ Version 0.245 }
			- Not support Kata patch 6.22

		{ Version 0.246 }
			- Delete Annie W Laneclear (fps drop)

		{ Version 0.25 + 0.26 }
			- Improve Fps

		{ Version 0.28 }
			- Added Kalista

-------------------------------------------]]
