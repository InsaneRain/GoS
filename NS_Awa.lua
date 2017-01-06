--[[ NS_Awa ver: 0.11
	Cooldown tracker
	Recall tracker
	Minimap Track
--]]

local NSAwa_Version = 0.11
local floor, ceil = math.floor, math.ceil
local enemies, allies = {}, {};
local function NSAwa_Print(text) PrintChat(string.format("<font color=\"#D9006C\"><b>[NS Awaraness]:</b></font><font color=\"#FFFFFF\"> %s</font>", tostring(text))) end

if not DirExists(SPRITE_PATH.."NS_Awa\\") then CreateDir(SPRITE_PATH.."NS_Awa\\") end
if not DirExists(SPRITE_PATH.."NS_Awa\\Spells\\") then CreateDir(SPRITE_PATH.."NS_Awa\\Spells\\") end
if not DirExists(SPRITE_PATH.."NS_Awa\\Hud\\") then CreateDir(SPRITE_PATH.."NS_Awa\\Hud\\") end
if not DirExists(SPRITE_PATH.."NS_Awa\\Champions\\") then CreateDir(SPRITE_PATH.."NS_Awa\\Champions\\") end

local Nothing, c, link, patch, dname, ch = true, 0, {}, {}, {}, {}
local function addToDownload(fd, name)
	c = c + 1
	link[c] = "https://raw.githubusercontent.com/VTNEETS/GoS/master/NSAwa/"..fd.."/"..name
	patch[c] = SPRITE_PATH.."NS_Awa\\"..fd.."\\"..name
	Nothing = false
	dname[c] = name
end

local function NSdownloadSprites()
	if c > 0 then
		NSAwa_Print(c.." file"..(c > 1 and "s" or "").." need to be download. Please wait...")
		local ps = function(n) NSAwa_Print("("..n.."/"..c..") "..dname[n]..". Don't Press F6!") end
		local download = function(n) DownloadFileAsync(link[n], patch[n], function() ps(n) sc(n+1) end) end
		sc = function(n) if n > c then NSAwa_Print("All file need have been downloaded. Please 2x F6!") return end DelayAction(function() download(n) end, 0.5) end
		DelayAction(function() download(1) end, 0.5)
	end
end

local function Toxyz(xVal, yVal, zVal)
	if type(xVal) == "table" then return { x = xVal.x or 0, y = xVal.y or 0, z = xVal.z or 0 } end
	return { x = xVal or 0, y = yVal or 0, z = zVal or 0 }
end

local hpbar1 = CreateSpriteFromFile("NS_Awa\\Hud\\HPBar.png", 1)
local hpbar2 = CreateSpriteFromFile("NS_Awa\\Hud\\HPBar2.png", 1)
local rcbar = CreateSpriteFromFile("NS_Awa\\Hud\\Recall.png", 1)
local dfcd = CreateSpriteFromFile("NS_Awa\\Spells\\cd.png", 1)
do
	if hpbar1 == 0 then addToDownload("Hud", "HPBar.png") end
	if hpbar2 == 0 then addToDownload("Hud", "HPBar2.png") end
	if rcbar == 0 then addToDownload("Hud", "Recall.png") end
	if dfcd == 0 then addToDownload("Spells", "cd.png") end
end

local recall, champ, sumDF = {}, {}, {}
local last, spellName = {{}, {}}, {{}, {}}
local menu, cMove, basePos = nil, false, nil

if mapID == SUMMONERS_RIFT then
	basePos = myHero.team == 100 and Toxyz(14300, 171, 14380) or Toxyz(410, 182, 420)
elseif mapID == TWISTED_TREELINE then
	basePos = myHero.team == 100 and Toxyz(14357, 151, 7295) or Toxyz(1065, 151, 7296)
elseif mapID == HOWLING_ABYSS then
	basePos = myHero.team == 100 and Toxyz(953, -131, 1059) or Toxyz(11800, -132, 11561)
elseif mapID == CRYSTAL_SCAR then
	basePos = myHero.team == 100 and Toxyz(14300, 171, 14380) or Toxyz(410, 182, 420)
end	

local fixbar = {
	["Annie"] = { x = 8, y = 7.5, x2 = 122, y2 = -20 },
	["Jhin"]  = { x = 8, y = 7.5, x2 = 122, y2 = -20 },
	["Other"] = { x = -3, y = 15, x2 = 131, y2 = -3 }
}
local rcf = {
	[1] = { 5, 20, 33, 46, 59 },
	[2] = { 18, 34, 48, 61, 76 }
}

local function CoolDownTracker()
	for i = 1, #enemies, 1 do
		local enemy = enemies[1];
		if not enemy.dead and enemy.visible and menu.cd.e[enemy.charName]:Value() then
			local bar = GetHPBarPos(enemy)
			if bar.x > 0 and bar.y > 0 then
				local posX1 = bar.x + (fixbar[enemy.charName] and fixbar[enemy.charName].x or fixbar.Other.x)
				local posY1 = bar.y + (fixbar[enemy.charName] and fixbar[enemy.charName].y or fixbar.Other.y)
				local posX2 = bar.x + (fixbar[enemy.charName] and fixbar[enemy.charName].x2 or fixbar.Other.x2)
				local posY2 = bar.y + (fixbar[enemy.charName] and fixbar[enemy.charName].y2 or fixbar.Other.y2)
				DrawSprite(hpbar1, posX1, posY1, 0, 1, 107, 10, GoS.White)
				DrawSprite(hpbar2, posX2, posY2, 0, 0, 37, 26, GoS.White)
				DrawSprite(sumDF[spellName[1][i][1]], posX2 + 2, posY2 + 2, 0, 0, 14, 14, GoS.White)
				DrawSprite(sumDF[spellName[1][i][2]], posX2 + 20, posY2 + 2, 0, 0, 14, 14, GoS.White)
				for slot = 0, 3, 1 do
					if GetGameTimer() < GetSpellData(enemy, slot).cdEndTime then
						local fullCD = GetSpellData(enemy, slot).spellCd
						local time = GetSpellData(enemy, slot).cdEndTime - GetGameTimer()
						DrawText(string.format("%2d", ceil(time)), 15, posX1+ 2 + 28*slot, posY1 + 7, GoS.White)
						FillRect(posX1+ 5 + 26*slot, posY1+2, (fullCD - time) * 21 / fullCD, 4, ARGB(255, 38, 159, 222))
					else
						if enemy:GetSpellData(slot).level > 0 then
							FillRect(posX1+ 5 + 26*slot, posY1+2, 21, 4, GoS.Green)
						end
					end
				end
				for slot = 4, 5, 1 do
					if GetGameTimer() < GetSpellData(enemy, slot).cdEndTime then
						local fullCD = GetSpellData(enemy, slot).spellCd
						local time = GetSpellData(enemy, slot).cdEndTime - GetGameTimer()
						DrawSprite(dfcd, posX2 + 2 + 18*(slot-4), posY2 + 2, 0, 0, 14, 14, GoS.White)
						DrawText(string.format("%2d", ceil(time)), 13, posX2 - 3 + 24*(slot-4), posY2 + 24, GoS.White)
						FillRect(posX2 + 3 + 18*(slot-4), posY2 + 19, (fullCD - time) * 13 / fullCD, 4, ARGB(255, 38, 159, 222))
					else
						if enemy:GetSpellData(slot).level > 0 then
							FillRect(posX2 + 3 + 18*(slot-4), posY2 + 19, 13, 4, GoS.Green)
						end
					end
				end
			end
		end
	end

	for i = 1, #allies, 1 do
		local ally = allies[i];
		if not ally.dead and menu.cd.a[ally.charName]:Value() then
			local bar = GetHPBarPos(ally)
			if bar.x > 0 and bar.y > 0 then
				local posX1 = bar.x + (fixbar[ally.charName] and fixbar[ally.charName].x or fixbar.Other.x)
				local posY1 = bar.y + (fixbar[ally.charName] and fixbar[ally.charName].y or fixbar.Other.y)
				local posX2 = bar.x + (fixbar[ally.charName] and fixbar[ally.charName].x2 or fixbar.Other.x2)
				local posY2 = bar.y + (fixbar[ally.charName] and fixbar[ally.charName].y2 or fixbar.Other.y2)
				DrawSprite(hpbar1, posX1, posY1, 0, 1, 107, 10, GoS.White)
				DrawSprite(hpbar2, posX2, posY2, 0, 0, 37, 26, GoS.White)
				DrawSprite(sumDF[spellName[2][i][1]], posX2 + 2, posY2 + 2, 0, 0, 14, 14, GoS.White)
				DrawSprite(sumDF[spellName[2][i][2]], posX2 + 20, posY2 + 2, 0, 0, 14, 14, GoS.White)
				for slot = 0, 3, 1 do
					if GetGameTimer() < GetSpellData(ally, slot).cdEndTime then
						local fullCD = GetSpellData(ally, slot).spellCd
						local time = GetSpellData(ally, slot).cdEndTime - GetGameTimer()
						DrawText(string.format("%2d", ceil(time)), 15, posX1+ 2 + 28*slot, posY1 + 7, GoS.White)
						FillRect(posX1+ 5 + 26*slot, posY1+2, (fullCD - time) * 21 / fullCD, 4, ARGB(255, 38, 159, 222))
					else
						if ally:GetSpellData(slot).level > 0 then
							FillRect(posX1+ 5 + 26*slot, posY1+2, 21, 4, GoS.Green)
						end
					end
				end
				for slot = 4, 5, 1 do
					if GetGameTimer() < GetSpellData(ally, slot).cdEndTime then
						local fullCD = GetSpellData(ally, slot).spellCd
						local time = GetSpellData(ally, slot).cdEndTime - GetGameTimer()
						DrawSprite(dfcd, posX2 + 2 + 18*(slot-4), posY2 + 2, 0, 0, 14, 14, GoS.White)
						DrawText(string.format("%2d", ceil(time)), 13, posX2 - 3 + 24*(slot-4), posY2 + 24, GoS.White)
						FillRect(posX2 + 3 + 18*(slot-4), posY2 + 19, (fullCD - time) * 13 / fullCD, 4, ARGB(255, 38, 159, 222))
					else
						if ally:GetSpellData(slot).level > 0 then
							FillRect(posX2 + 3 + 18*(slot-4), posY2 + 19, 13, 4, GoS.Green)
						end
					end
				end
			end
		end
	end
end

local function RecallTracker()
	if menu.rc.cm:Value() and cMove and CursorIsUnder(menu.rc.px:Value()-15, menu.rc.py:Value()-20, 345, 33) then
		menu.rc.px.value = GetCursorPos().x - 165
		menu.rc.py.value = GetCursorPos().y
	end
	if #recall > 0 or menu.rc.cm:Value() then DrawSprite(rcbar, menu.rc.px:Value(), menu.rc.py:Value(), 0, 0, 330, 13, GoS.White) end
	for i = 1, #recall, 1 do
		recall[i].cTime = (recall[i].fT - GetGameTimer() + recall[i].sT)
		local rec = recall[i]
		if rec.stopT then
			recall[i].cTime = (recall[i].fT - recall[i].stopT + recall[i].sT)
			if GetGameTimer() > rec.stopT + 0.5 then
				table.remove(recall, i)
				return
			end
		end
		FillRect(menu.rc.px:Value() + 3, menu.rc.py:Value() + 1, rec.cTime * 324 / rec.fT, 11, rec.color(i))
		FillRect(menu.rc.px:Value() + 3 + rec.cTime * 324 / rec.fT, menu.rc.py:Value() - rcf[1][i], 1, 12*i, GoS.White)
		DrawText(string.format("%s (%d | %.1f)", rec.unit.charName, math.round(rec.unit.health), rec.cTime), 15, menu.rc.px:Value() + 3 + rec.cTime * 324 / rec.fT, menu.rc.py:Value() - rcf[2][i], GoS.White)
	end
end

local function MinimapTrack()
	for i = 1, #enemies, 1 do
		local enemy = enemies[i];
		if menu.mm[enemy.charName]:Value() and not enemy.visible and not enemy.dead then
			local pos = WorldToMinimap(last[2][enemy.networkID])
			DrawSprite(champ[i], pos.x - 10.8, pos.y - 10.8, 0, 0, 21.6, 21.6, GoS.White)
			local time = GetGameTimer() - last[1][enemy.networkID]
			local mp = enemy.ms*time
			if mp < 4300 then DrawCircleMinimap(last[2][enemy.networkID], mp, 1, 255, 0x9000F5FF) end
			if time < 60 then
				DrawText(string.format("%2d", floor(time)), 12, pos.x - 7.5, pos.y + 5, GoS.White)
			else
				local uiTime = floor(time)
				DrawText(string.format("%2d:%02d", uiTime/60, uiTime%60), 12, pos.x - 14, pos.y + 5, GoS.White)
			end
		end
	end
end

local function Load()
	OnUnLoad(function()
		if hpbar1 > 0 then ReleaseSprite(hpbar1) end
		if hpbar2 > 0 then ReleaseSprite(hpbar2) end
		if dfcd > 0 then ReleaseSprite(dfcd) end
		if rcbar > 0 then ReleaseSprite(rcbar) end

		for i = 1, #enemies, 1 do
			local enemy = enemies[i];
			local NAME = spellName[1][i][1];
			if sumDF[NAME] > 0 then
				ReleaseSprite(sumDF[NAME])
				sumDF[NAME] = 0
			end
			NAME = spellName[1][i][2];
			if sumDF[NAME] > 0 then
				ReleaseSprite(sumDF[NAME])
				sumDF[NAME] = 0
			end

			if champ[i] > 0 then ReleaseSprite(champ[i]) end
		end

		for i = 1, #allies, 1 do
			local ally = allies[i];
			local NAME = spellName[2][i][1];
			if sumDF[NAME] > 0 then
				ReleaseSprite(sumDF[NAME])
				sumDF[NAME] = 0
			end
			NAME = spellName[2][i][2];
			if sumDF[NAME] > 0 then
				ReleaseSprite(sumDF[NAME])
				sumDF[NAME] = 0
			end
		end
	end)

	OnWndMsg(function(msg, key)
		if msg == 513 then
			cMove = true
		elseif msg == 514 then
			cMove = false
		end
	end)

	OnProcessRecall(function(unit, rec)
		if unit.team == myHero.team then return end
		if rec.isStart then
			recall[#recall + 1] = { unit = unit, sT = GetGameTimer(), fT = rec.totalTime*0.001, color = function(i) if rec.totalTime <= 4 then return ARGB(280 - 45*i, 181, 19, 210) end return ARGB(280 - 45*i, 255, 255, 255) end }
		else
			if rec.isFinish or (rec.totalTime <= 4 and rec.passedTime >= 3940 or rec.passedTime >= 7940) then last[2][unit.networkID] = basePos end
			for i = 1, #recall, 1 do
				if recall[i].unit.networkID == unit.networkID then
					if rec.isFinish or (rec.totalTime <= 4 and rec.passedTime >= 3940 or rec.passedTime >= 7940) then
						table.remove(recall, i)
					else
						recall[i].stopT = GetGameTimer()
						recall[i].color = function(i) if rec.totalTime <= 4 then return ARGB(280 - 45*i, 159, 11, 196) end return ARGB(280 - 45*i, 208, 198, 198) end
					end
					return
				end
			end
		end
	end)

	OnLoseVision(function(unit)
		if unit.type == "AIHeroClient" and unit.team ~= myHero.team then
			last[1][unit.networkID] = GetGameTimer()
			last[2][unit.networkID] = not unit.dead and Toxyz(unit.pos) or basePos
		end
	end)

	OnDraw(function()
		CoolDownTracker()
		if menu.rc.on:Value() then RecallTracker() end
	end)

	OnDrawMinimap(function() MinimapTrack() end)
end

class "NS_Awaraness"
function NS_Awaraness:__init(Menu)
	if menu then return end
	menu = Menu
	menu:Menu("cd", "Cooldown Tracker")
		menu.cd:Menu("e", "Track Enemies")
		menu.cd:Menu("a", "Track Allies")
	menu:Menu("rc", "Recall Tracker")
		menu.rc:Boolean("on", "Enable?", true)
		menu.rc:Boolean("cm", "Move recall bar", false)
		menu.rc:Slider("px", "Horizontal", GetResolution().x/2.8, 1, GetResolution().x, 0.001)
		menu.rc:Slider("py", "Vertical", GetResolution().y/1.5, 1, GetResolution().y, 0.001)
	menu:Menu("mm", "Track Minimap")
	OnLoad(function()
		enemies = GetEnemyHeroes();
		allies = GetAllyHeroes();
		for i = 1, #enemies, 1 do
			local enemy = enemies[i];
			menu.cd.e:Boolean(enemy.charName, "Track "..enemy.charName, true)
			menu.mm:Boolean(enemy.charName, "Track "..enemy.charName, true)
			spellName[1][i] = {nil, nil}
			for j = 1, 2, 1 do
				spellName[1][i][j] = enemy:GetSpellData(j+3).name:lower();
			end

			local NAME = spellName[1][i][1]
			if not FileExist(SPRITE_PATH.."NS_Awa\\Spells\\"..NAME..".png") then
				if not ch[NAME] then
					addToDownload("Spells", NAME..".png")
					ch[NAME] = true
				end
			else
				if sumDF[NAME] == nil then
					sumDF[NAME] = CreateSpriteFromFile("NS_Awa\\Spells\\"..NAME..".png", 1)
				end
			end

			NAME = spellName[1][i][2]
			if not FileExist(SPRITE_PATH.."NS_Awa\\Spells\\"..NAME..".png") then
				if not ch[NAME] then
					addToDownload("Spells", NAME..".png")
					ch[NAME] = true
				end
			else
				if sumDF[NAME] == nil then
					sumDF[NAME] = CreateSpriteFromFile("NS_Awa\\Spells\\"..NAME..".png", 1)
				end
			end

			champ[i] = CreateSpriteFromFile("NS_Awa\\Champions\\"..enemy.charName..".png", 0.4)
			if champ[i] == 0 then addToDownload("Champions", enemy.charName..".png") end
			last[1][enemy.networkID] = GetGameTimer()
			last[2][enemy.networkID] = Toxyz(enemy.pos)
		end

		for i = 1, #allies, 1 do
			local ally = allies[i];
			menu.cd.a:Boolean(ally.charName, "Track "..ally.charName, true)
			spellName[2][i] = {};
			for j = 1, 2, 1 do
				spellName[2][i][j] = ally:GetSpellData(j+3).name:lower();
			end

			local NAME = spellName[2][i][1]
			if not FileExist(SPRITE_PATH.."NS_Awa\\Spells\\"..NAME..".png") then
				if not ch[NAME] then
					addToDownload("Spells", NAME..".png")
					ch[NAME] = true
				end
			else
				if sumDF[NAME] == nil then
					sumDF[NAME] = CreateSpriteFromFile("NS_Awa\\Spells\\"..NAME..".png", 1)
				end
			end

			NAME = spellName[2][i][2]
			if not FileExist(SPRITE_PATH.."NS_Awa\\Spells\\"..NAME..".png") then
				if not ch[NAME] then
					addToDownload("Spells", NAME..".png")
					ch[NAME] = true
				end
			else
				if sumDF[NAME] == nil then
					sumDF[NAME] = CreateSpriteFromFile("NS_Awa\\Spells\\"..NAME..".png", 1)
				end
			end
		end

		if mapID == 12 then
			if not FileExist(SPRITE_PATH.."NS_Awa\\Spells\\snowballfollowupcast.png") then
				if not ch["snowballfollowupcast"] then
					addToDownload("Spells", "snowballfollowupcast.png")
					ch["snowballfollowupcast"] = true
				end
			else
				sumDF["snowballfollowupcast"] = CreateSpriteFromFile("NS_Awa\\Spells\\snowballfollowupcast.png", 1)
			end

			if not FileExist(SPRITE_PATH.."NS_Awa\\Spells\\summonersnowball.png") then
				if not ch["summonersnowball"] then
					addToDownload("Spells", "summonersnowball.png")
					ch["summonersnowball"] = true
				end
			else
				sumDF["summonersnowball"] = CreateSpriteFromFile("NS_Awa\\Spells\\summonersnowball.png", 1)
			end
		end

		menu:Info("ifo", "[NS Awaraness] - Ver: "..NSAwa_Version)
		NSdownloadSprites()
		if not Nothing then return end
		Load()
		GetWebResultAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NS_Awa.version", function(OnlineVer)
			if tonumber(OnlineVer) > NSAwa_Version then
				NSAwa_Print("New Version found (v"..OnlineVer.."). Please wait...")
				DownloadFileAsync("https://raw.githubusercontent.com/VTNEETS/GoS/master/NS_Awa.lua", COMMON_PATH.."NS_Awa.lua", function() NSAwa_Print("Updated to version "..OnlineVer..". Please F6 x2 to reload.") end)
			else
				NSAwa_Print("Loaded Version: "..NSAwa_Version)
			end
		end)
	end)
end
