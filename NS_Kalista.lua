local eDmg = {10, 14, 19, 25, 32}
eDmg[0] = 0
local eRange = myHero:GetSpellData(_E).range
local Enemies = LoadEnemies()
local Creeps = __MinionManager(eRange, eRange)
local HPBar, eTbl, damage = { }, { }, 0
local function IsSReady(spell) return CanUseSpell(myHero, spell) == 0 or CanUseSpell(myHero, spell) == 8 end
local QData = {delay = 0.25, speed = 2000, width = 80, range = myHero:GetSpellData(_Q).range + myHero.boundingRadius, type = "linear", colNum = 1, slot = 0}
local NS_Kalista = MenuConfig("NS_Kalista", "[NEET Series] - Kalista")
NS_Kalista:Menu("lc", "Lane Clear")
	NS_Kalista.lc:Boolean("supm", "Super minion", true)
	NS_Kalista.lc:Boolean("siem", "Siege minion", true)
	NS_Kalista.lc:Slider("at", "Auto E if killable x minions", 2, 1, 30, 1)
	NS_Kalista.lc:Boolean("eb", "Only enable if press farm key", true)
NS_Kalista:Menu("jc", "Jungle Clear")
	if GetMapID() == SUMMONERS_RIFT then
		NS_Kalista.jc:Boolean("SRU_Krug", "Krug (big)", true)
		NS_Kalista.jc:Boolean("SRU_KrugMini", "Krug (normal)", true)
		NS_Kalista.jc:Boolean("SRU_KrugMiniMini", "Krug (small)", false)
		NS_Kalista.jc:Boolean("SRU_Razorbeak", "Razorbeak (big)", true)
		NS_Kalista.jc:Boolean("SRU_RazorbeakMini", "Razorbeak (small)", false)
		NS_Kalista.jc:Boolean("SRU_Murkwolf", "Wolf (big)", true)
		NS_Kalista.jc:Boolean("SRU_MurkwolfMini", "Wolf (small)", false)
		NS_Kalista.jc:Boolean("SRU_Red", "Red", true)
		NS_Kalista.jc:Boolean("SRU_Blue", "Blue", true)
		NS_Kalista.jc:Boolean("SRU_Gromp", "Gromp", true)
		NS_Kalista.jc:Boolean("Sru_Crab", "Crab", true)
		NS_Kalista.jc:Boolean("SRU_Dragons", "Dragons", true)
		NS_Kalista.jc:Boolean("SRU_Baron", "Baron", true)
		NS_Kalista.jc:Boolean("SRU_RiftHerald", "Rift Herald", true)
	elseif GetMapID() == CRYSTAL_SCAR then
		NS_Kalista.jc:Boolean("AscXerath", "Xerath so big", true)
	elseif GetMapID() == TWISTED_TREELINE then
		NS_Kalista.jc:Boolean("TT_Spiderboss", "Spider", true)
		NS_Kalista.jc:Boolean("TT_NGolem", "Golem (big)", true)
		NS_Kalista.jc:Boolean("TT_NGolem2", "Golem (small)", true)
		NS_Kalista.jc:Boolean("TT_NWraith", "Wraith (big)", true)
		NS_Kalista.jc:Boolean("TT_NWraith2", "Wraith (small)", true)
		NS_Kalista.jc:Boolean("TT_NWolf", "Wolf (big)", true)
		NS_Kalista.jc:Boolean("TT_NWolf2", "Wolf (small)", true)
	end
	NS_Kalista.jc:Boolean("eb", "Only enable if press farm key", false)
NS_Kalista:Menu("Q", "Q Settings")
	NS_Kalista.Q:Boolean("Q", "Use Q in combo", true)
	LoadPredMenu(NS_Kalista.Q)
	QSpell = AddSpell(QData, NS_Kalista.Q, NS_Kalista.Q.cpred:Value(), 2)
NS_Kalista:Menu("dw", "Drawings")
local Draw = {
	[0] = DCircle(NS_Kalista.dw, "Q", "Draw Q Range", QData.range, ARGB(150, 0, 245, 255)),
	[2] = DCircle(NS_Kalista.dw, "E", "Draw E Range", eRange, ARGB(150, 186, 85, 211)),
}

OnLoad(function()
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		eTbl[enemy.networkID] = GotBuff(enemy, "kalistaexpungemarker")
		NS_Kalista:Menu(i, "Draw DmgHP Bar "..enemy.charName)
		HPBar[i] = DrawDmgHPBar(NS_Kalista[i], enemy, {ARGB(170, 0, 0, 0)}, {"E"})
	end
end)

OnUpdateBuff(function(unit, buff) 
	if unit.team ~= myHero.team and buff.Name == "kalistaexpungemarker" then
		eTbl[unit.networkID] = buff.Count + 1
	end
end)

OnRemoveBuff(function(unit, buff) 
	if unit.team ~= myHero.team and buff.Name == "kalistaexpungemarker" then
		eTbl[unit.networkID] = 0
	end
end)

OnGainVision(function(unit) 
	if unit.team ~= myHero.team and (unit.type == Obj_AI_Hero or unit.type == Obj_AI_Minion) and not unit.dead then
		eTbl[unit.networkID] = GotBuff(unit, "kalistaexpungemarker")
	end
end)

OnProcessSpellComplete(function(unit, spell) 
	if unit == myHero and IsReady(_Q) and spell.name:lower():find("attack") then
		local target = spell.target
		if target.isHero and ValidTarget(target, QData.range) then QSpell:Cast(target) end
	end
end)

local function DmgHPBar(i, dmg)
	HPBar[i]:SetValue(1, dmg, true)
	HPBar[i]:CheckValue()
	HPBar[i]:UpdatePos()
	HPBar[i]:Draw()
	local data = HPBar[i]:GetPos(1)
	FillRect(data.x, data.y, 1, 9, ARGB(220, 255, 255, 0))
end

local function EKillCheck(unit, index)
	if not eTbl[unit.networkID] or eTbl[unit.networkID] == 0 then return end
	local dmg = myHero:CalcDamage(unit, 10 + 10*myHero:GetSpellData(_E).level + 0.6*myHero.totalDamage + damage*(eTbl[unit.networkID] - 1))
	local hp = unit.health + unit.shieldAD
	local count = dmg/hp * 100
	if count > 100 then count = 100 end
	if index then DmgHPBar(index, dmg) end
	return math.round(count)
end

OnTick(function()
	if myHero.dead then return end
	Creeps:Update()
	damage = eDmg[myHero:GetSpellData(_E).level] + (0.175 + 0.025*myHero:GetSpellData(_E).level)*myHero.totalDamage
end)

OnDraw(function()
	if myHero.dead then return end
	if IsSReady(_Q) then Draw[0]:Draw(myHero.pos) end
	if not IsSReady(_E) then return end
	Draw[2]:Draw(myHero.pos)
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if ValidTarget(enemy, eRange) then
			local perc = EKillCheck(enemy, i)
			if perc then
				if perc == 100 and IsReady(_E) then CastSpell(_E) return end
				local hpbar = enemy.hpBarPos
				DrawText(perc.."%", 22, hpbar.x + 100, hpbar.y + 23, GoS.White)
			end
		end
	end
	local mode = Mix:Mode()
	if not NS_Kalista.jc.eb:Value() or (NS_Kalista.jc.eb:Value() and mode == "LaneClear") then
		for i = 1, #Creeps.tmob, 1 do
			local mob = Creeps.tmob[i]
			local enable = NS_Kalista.jc[mob.charName]
			if (mob.charName:find("SRU_Dragon") and NS_Kalista.jc["SRU_Dragons"]:Value()) or (enable and enable:Value()) then
				local perc = EKillCheck(mob)
				if perc then
					if perc == 100 and IsReady(_E) then CastSpell(_E) return end
					DrawText3D(perc.."%", mob.pos.x, mob.pos.y, mob.pos.z, 22, GoS.Cyan, true)
				end
			end
		end
	end
	if not NS_Kalista.lc.eb:Value() or (NS_Kalista.lc.eb:Value() and mode == "LaneClear") then
		local cnt = 0
		for i = 1, #Creeps.tminion, 1 do
			local minion = Creeps.tminion[i]
			local perc = EKillCheck(minion)
			if perc and perc == 100 then
				cnt = cnt + 1
				if cnt >= NS_Kalista.lc.at:Value() or (minion.charName:find("Siege") and NS_Kalista.lc.sie:Value()) or (minion.charName:find("Super") and NS_Kalista.lc.sup:Value()) and IsReady(_E) then
					CastSpell(_E)
				return end
			end
		end
	end
end)
