--[[ NEETSeries's plugin
	 ___  ___  _______   _______        __  ___________  __    __   
	|"  \/"  |/"     "| /"      \      /""\("     _   ")/" |  | "\  
	 \   \  /(: ______)|:        |    /    \)__/  \\__/(:  (__)  :) 
	  \\  \/  \/    |  |_____/   )   /' /\  \  \\_ /    \/      \/  
	  /\.  \  // ___)_  //      /   //  __'  \ |.  |    //  __  \\  
	 /  \   \(:      "||:  __   \  /   /  \\  \\:  |   (:  (  )  :) 
	|___/\___|\_______)|__|  \___)(___/    \___)\__|    \__|  |__/  

---------------------------------------]]

local Enemies, HPBar, CCast, mode = LoadEnemies(), { }, false, ""
local Check = Set {"Run", "Idle1", "Channel_WNDUP"}
local Ignite = Mix:GetSlotByName("summonerdot", 4, 5)
local function CalcDmg(type, target, dmg) if type == 1 then return CalcPhysicalDamage(myHero, target, dmg) end return CalcMagicalDamage(myHero, target, dmg) end
local function IsSReady(spell) return CanUseSpell(myHero, spell) == 0 or CanUseSpell(myHero, spell) == 8 end
local function ManaCheck(value) return value <= GetPercentMP(myHero) end
local function EnemiesAround(pos, range) return CountObjectsNearPos(pos, nil, range, Enemies.List, MINION_ENEMY) end

local function AddMenu(Menu, ID, Text, Tbl, MP)
	local StrID, StrN = {"cb", "hr", "lc", "jc", "ks", "lh"}, {"Combo", "Harass", "LaneClear", "JungleClear", "KillSteal", "LastHit"}
	Menu:Menu(ID, Text)
	for i = 1, 6 do
		if Tbl[i] then Menu[ID]:Boolean(StrID[i], "Use in "..StrN[i], true) end
		if MP and i > 1 and Tbl[i] then Menu[ID]:Slider("MP"..StrID[i], "Enable in "..StrN[i].." if %MP >=", MP, 1, 100, 1) end
	end
end

local function SetSkin(Menu, skintable)
	local ChangeSkin = function(id) myHero:Skin(id == #skintable and -1 or id) end
	Menu:DropDown("SetSkin", myHero.charName.." SkinChanger", #skintable, skintable, function(id) ChangeSkin(id) end)
	if (Menu["SetSkin"]:Value() ~= #skintable) then ChangeSkin(Menu["SetSkin"]:Value()) end
end

local function DrawDmgOnHPBar(Menu, Color, Text)
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		Menu:Menu(i, "Draw Dmg HPBar "..enemy.charName)
		HPBar[i] = DrawDmgHPBar(Menu[i], enemy, Color, Text)
	end
end

local GetLineFarmPosition2 = function (range, width, objects)
	local Pos, Hit = nil, 0
	for i = 1, #objects, 1 do
		local m = objects[i]
		if ValidTarget(m, range) then
			local count = CountObjectsOnLineSegment(Vector(myHero), Vector(m), width, objects, MINION_ENEMY)
			if not Pos or CountObjectsOnLineSegment(Vector(myHero), Vector(Pos), width, objects, MINION_ENEMY) < count then
				Pos = m.pos
				Hit = count
			end
		end
	end
		return Pos, Hit
end

local GetFarmPosition2 = function(range, width, objects)
	local Pos, Hit = nil, 0
	for i = 1, #objects, 1 do
		local m = objects[i]
		if ValidTarget(m, range) then
			local count = CountObjectsNearPos(Vector(m), nil, width, objects, MINION_ENEMY)
			if not Pos or CountObjectsNearPos(Vector(Pos), nil, width, objects, MINION_ENEMY) < count then
				Pos = m.pos
				Hit = count
			end
		end
	end
		return Pos, Hit
end

OnAnimation(function(u, a)
	if (u ~= myHero or u.dead) then return end
	if (Check[a]) then CCast = true return end
	if (a:lower():find("attack")) then CCast = false return end
end)

OnProcessSpellAttack(function(u, a)
	if (u ~= myHero or u.dead) then return end
	if (a.name:lower():find("attack")) then CCast = false return end
end)

OnProcessSpellComplete(function(u, a)
	if (u ~= myHero or u.dead) then return end
	if (a.name:lower():find("attack")) then CCast = true return end
end)
--------------------------------------------------------------------------------

local QRange = {750, 750, 1460}
local Data = {
	[0] = { range = QRange[3],                                 speed = math.huge, delay = 0.6,  width = 180, type = "linear", colNum = 0, slot = 0 },
	[1] = { range = myHero:GetSpellData(_W).range,             speed = math.huge, delay = 0.85, width = 400, type = "circular", colNum = 0, slot = 1 },
	[2] = { range = myHero:GetSpellData(_E).range,             speed = 1500,      delay = 0.25, width = 140, type = "linear", colNum = 1, slot = 2 },
	[3] = { range = 2000 + 1200*myHero:GetSpellData(_R).level, speed = math.huge, delay = 0.72, width = 380, type = "circular", colNum = 0, slot = 3 }
}
local Damage = {
	[0] = function(unit) return CalcDmg(2, unit, 40 + 40*myHero:GetSpellData(_Q).level + 0.75*myHero.ap) end,
	[1] = function(unit) return CalcDmg(2, unit, 45 + 45*myHero:GetSpellData(_W).level + 0.9*myHero.ap) end,
	[2] = function(unit) return CalcDmg(2, unit, 50 + 30*myHero:GetSpellData(_E).level + 0.45*myHero.ap) end,
	[3] = function(unit) return CalcDmg(2, unit, 170 + 30*myHero:GetSpellData(_R).level + 0.43*myHero.ap) end
}
local Castable = {
	[0] = false,
	[1] = false,
	[2] = false,
	[3] = false
}
local LastCastTime = {
	[0] = 0,
	[1] = 0,
	[2] = 0
}
local RDelay = {0, 0, 0, 0, 0}
local RCount = math.max(3, myHero:GetSpellData(_R).level + 2)
local RActive = false
local QActive = false

if GotBuff(myHero, "XerathLocusOfPower2") > 0 then
	RActive = true
	RDelay[1] = GetGameTimer()
end

local Cr = __MinionManager(QRange[3], Data[1].range)
local function CanCast(t, target)
	if (t == "W" and WObj and GetDistanceSqr(myHero, WObj.pos) >= GetDistanceSqr(myHero, target.pos)) then
		return false
	end
	if (t == "E" and WObj and GetDistanceSqr(myHero, EObj.pos) >= GetDistanceSqr(myHero, target.pos)) then
		return false
	end
	return true
end

local NS_Xe = MenuConfig("NS_Xerath", "[NEET Series] - Xerath")

	--[[ Q Settings ]]--
	AddMenu(NS_Xe, "Q", "Q Settings", {true, true, true, true, true, false}, 15)
	NS_Xe.Q:Slider("h", "Q LaneClear if hit Minions >= ", 2, 1, 10, 1)

	--[[ W Settings ]]--
	AddMenu(NS_Xe, "W", "W Settings", {true, true, true, true, true, false}, 15)
	NS_Xe.W:Slider("h", "W LaneClear if hit Minions >= ", 2, 1, 10, 1)

	--[[ E Settings ]]--
	AddMenu(NS_Xe, "E", "E Settings", {true, true, false, true, true, false}, 15)

	--[[ Ignite Settings ]]--
	if Ignite then AddMenu(NS_Xe, "Ignite", "Ignite Settings", {false, false, false, false, true, false}) end

	--[[ Ultimate Menu ]]--
	NS_Xe:Menu("ult", "Ultimate Settings")
		NS_Xe.ult:Menu("cast", "Casting Mode")
			NS_Xe.ult.cast:DropDown("mode", "Choose Your Mode:", 1, {"Press Key", "Auto Cast", "Target In Mouse Range"})
			NS_Xe.ult.cast:KeyBinding("key", "Seclect Key For PressKey Mode:", 84)
			NS_Xe.ult.cast:Slider("range", "Range for Target NearMouse", 500, 200, 1500, 50, function(value) R.Draw2:Update("Range", value) end)
			NS_Xe.ult.cast:Info("if1", "Press Key: Press a Key for AutoCast")
			NS_Xe.ult.cast:Info("if2", "Auto Cast: AutoCast Target")
			NS_Xe.ult.cast:Info("if3", "Mouse: AutoCast Target in Mouse Range")
			NS_Xe.ult.cast:Info("if4", "Recommend using Press Key")
			NS_Xe.ult.cast:Info("if5", "You must EnableR -manually-")

	--[[ Misc Menu ]]--
	NS_Xe:Menu("misc", "Misc Mode")
		NS_Xe.misc:Menu("castCombo", "Combo Casting")
			NS_Xe.misc.castCombo:Info("info", "Only Cast QWE if W or E Ready")
			NS_Xe.misc.castCombo:Boolean("WE", "Enable? (default off)", false)
		NS_Xe.misc:Menu("delay", "R Casting Delays")
			NS_Xe.misc.delay:Slider("c1", "Delay CastR 1 (ms)", 230, 0, 1500, 1)
			NS_Xe.misc.delay:Slider("c2", "Delay CastR 2 (ms)", 250, 0, 1500, 1)
			NS_Xe.misc.delay:Slider("c3", "Delay CastR 3 (ms)", 270, 0, 1500, 1)
			NS_Xe.misc.delay:Slider("c4", "Delay CastR 4 (ms)", 290, 0, 1500, 1)
			NS_Xe.misc.delay:Slider("c5", "Delay CastR 5 (ms)", 310, 0, 1500, 1)
		NS_Xe.misc:KeyBinding("E", "Use E in Combo/Harass (Z)", 90, true, function() end, true)
		NS_Xe.misc:KeyBinding("escape", "Escape use W/E (G)", 71)
		SetSkin(NS_Xe.misc, {"Runeborn", "Battlecast", "Scorched Earth", "Guardian Of The Sands", "Disable"})

	--[[ Drawings Menu ]]--
	NS_Xe:Menu("dw", "Draw Settings")
		NS_Xe.dw:Boolean("Rmm", "Draw R Range Minimap", true)
		NS_Xe.dw:Boolean("TK", "Draw Text Target R Killable", true)

	LoadPredMenu(NS_Xe)
	PermaShow(NS_Xe.misc.escape)
	PermaShow(NS_Xe.misc.E)
-----------------------------------

local Target = {
	[0] = ChallengerTargetSelector(QRange[3], 2, false, nil, false, NS_Xe.Q, false),
	[1] = ChallengerTargetSelector(Data[1].range, 2, false, nil, false, NS_Xe.W, false),
	[2] = ChallengerTargetSelector(Data[2].range, 2, true, nil, false, NS_Xe.E, false, 7)
}
Target[0].Menu.TargetSelector.TargetingMode.callback = function(id) Target[0].Mode = id end
Target[1].Menu.TargetSelector.TargetingMode.callback = function(id) Target[1].Mode = id end
Target[2].Menu.TargetSelector.TargetingMode.callback = function(id) Target[2].Mode = id end

local Draw = {
	DCircle(NS_Xe.dw, "QMax", "Draw Q Full Range", QRange[3], ARGB(150, 0, 245, 255)),
	DCircle(NS_Xe.dw, "W", "Draw W Range", Data[1].range, ARGB(150, 186, 85, 211)),
	DCircle(NS_Xe.dw, "E", "Draw E Range", Data[2].range, ARGB(150, 0, 217, 108)),
	DCircle(NS_Xe.dw, "R", "Draw R Range", Data[3].range, ARGB(150, 89, 0 ,179)),
	DCircle(NS_Xe.dw, "Qcurrent", "Draw Q Current Range", QRange[1], ARGB(150, 0, 245, 255)),
	DCircle(NS_Xe.ult.cast, "Rmouse", "Draw NearMouse Range", NS_Xe.ult.cast.range:Value(), ARGB(150, 255, 255, 0))
}

local Spells = {
	[0] = AddSpell(Data[0], NS_Xe.Q, NS_Xe.cpred:Value()),
	[1] = AddSpell(Data[1], NS_Xe.W, NS_Xe.cpred:Value()),
	[2] = AddSpell(Data[2], NS_Xe.E, NS_Xe.cpred:Value()),
	[3] = AddSpell(Data[3], NS_Xe.ult, NS_Xe.cpred:Value())
}

ChallengerAntiGapcloser(NS_Xe.misc, function(o, s) if not ValidTarget(o, Data[2].range) or not Castable[2] then return end Spells[2]:Cast(o) end)
ChallengerInterrupter(NS_Xe.misc, function(o, s) if not ValidTarget(o, Data[2].range) or not Castable[2] then return end Spells[2]:Cast(o) end)
-----------------------------------

local function CastR(target)
	if not target or RCount == 0 then return end

	local index = myHero:GetSpellData(3).level - RCount + 3
	if GetGameTimer() - RDelay[index] >= NS_Xe.misc.delay["c"..index]:Value()*0.001 then
		Spells[3]:Cast(target)
	end
end

local function CastQ(target)
	if not Castable[0] or not ValidTarget(target, QRange[3] + 80) then return end
	if not QActive then
		if GetGameTimer() - LastCastTime[1] > 0.1 and CanCast("W", target) and CanCast("E", target) then CastSkillShot(_Q, GetMousePos()) end
	else
		Spells[0]:Cast(target, QRange[1])
	end
end

local function CastW(target)
	if not Castable[1] or not ValidTarget(target, Data[1].range) or not CanCast("E", target) or GetGameTimer() - LastCastTime[0] < 0.2 or GetGameTimer() - LastCastTime[2] < 0.3 then return end
		Spells[1]:Cast(target)
end

local function CastE(target)
	if not Castable[2] or not ValidTarget(target, Data[2].range) or not CanCast("W", target) or GetGameTimer() - LastCastTime[0] < 0.2 or GetGameTimer() - LastCastTime[1] < 0.3 then return end
		Spells[2]:Cast(target)
end

local function GetRTarget(pos, range)
	local RTarget = nil
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if ValidTarget(enemy, Data[3].range) and GetDistanceSqr(pos, enemy.pos) <= range * range then
			if not RTarget or GetHP2(enemy) - Damage[3](enemy) * RCount < GetHP2(RTarget) - Damage[3](RTarget) * RCount then
				RTarget = enemy
			end
		end
	end
		return RTarget
end

local function CheckRCasting()
	if NS_Xe.ult.cast.mode:Value() < 3 then
		local target = GetRTarget(myHero.pos, Data[3].range)
		if NS_Xe.ult.cast.mode:Value() == 1 and NS_Xe.ult.cast.key:Value() then
			CastR(target)
		else
			CastR(target)
		end
	else
		local target = GetRTarget(GetMousePos(), NS_Xe.ult.cast.range:Value())
		CastR(target)
	end
end

local function Updating()
	Castable[0] = IsReady(0);
	Castable[1] = IsReady(1);
	Castable[2] = IsReady(2);
	Castable[3] = IsReady(3);
	Data[3].range = 2000 + 1200*myHero:GetSpellData(_R).level;

	if Castable[0] and QActive then
		QRange[1] = math.min(QRange[2] + (GetGameTimer() - LastCastTime[0])*500, QRange[3])
	end
	if Castable[3] and RActive then
		CheckRCasting()
		if EnemiesAround(myHero.pos, 1000) == 0 then
			Mix:BlockOrb(true)
		else
			Mix:BlockOrb(false)
		end
	end

	if WObj and GetGameTimer() - LastCastTime[1] >= Data[1].delay then WObj = nil end
	if EObj and GetGameTimer() - LastCastTime[2] >= Data[2].range/Data[2].speed then EObj = nil end

	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if ValidTarget(enemy, Data[3].range) and HPBar[i] then
			HPBar[i]:SetValue(1, Damage[3](enemy)*RCount, IsSReady(_R))
			HPBar[i]:SetValue(2, Damage[0](enemy), IsSReady(_Q))
			HPBar[i]:SetValue(3, Damage[1](enemy), IsSReady(_W))
			HPBar[i]:SetValue(4, Damage[2](enemy), IsSReady(_E))
			HPBar[i]:CheckValue()
		end
	end

	if Castable[0] then Draw[5]:Update("range", QRange[1]) end
	if Castable[3] then Draw[4]:Update("range", Data[3].range) end

end

local function ProcSpellCast(unit, spell)
	if unit == myHero then
		if spell.name:lower() == "xeratharcanebarrage2" then
			LastCastTime[1] = GetGameTimer() + spell.windUpTime
		elseif spell.name:lower() == "xerathmagespear" then
			LastCastTime[2] = GetGameTimer() + 0.3
		end

		if spell.name:lower() ~= "xerathlocuspulse" then return end
		RCount = RCount - 1
		local time = GetGameTimer() + 0.6
		local count = 2 + myHero:GetSpellData(_R).level
		if count == 3 then
			if RCount == 2 then
				RDelay[2] = time
			elseif RCount == 1 then
				RDelay[3] = time
			end
		elseif count == 4 then
			if RCount == 3 then
				RDelay[2] = time
			elseif RCount == 2 then
				RDelay[3] = time
			elseif RCount == 1 then
				RDelay[4] = time
			end
		elseif count == 5 then
			if RCount == 4 then
				RDelay[2] = time
			elseif RCount == 3 then
				RDelay[3] = time
			elseif RCount == 2 then
				RDelay[4] = time
			elseif RCount == 1 then
				RDelay[5] = time
			end
		end
	end
end

local function UpdateBuff(unit, buff)
	if unit == myHero and not unit.dead then
		if buff.Name:lower() == "xeratharcanopulsechargeup" then
			LastCastTime[0] = GetGameTimer()
			QActive = true
		elseif buff.Name:lower() == "xerathlocusofpower2" then
			RCount = myHero:GetSpellData(_R).level + 2
			RDelay[1] = GetGameTimer()
			RActive = true
		end
	end
end

local function RemoveBuff(unit, buff)
	if unit == myHero and not unit.dead then
		if buff.Name:lower() == "xeratharcanopulsechargeup" then
			QActive = false
			QRange[1] = QRange[2]
		elseif buff.Name:lower() == "xerathlocusofpower2" then
			RActive = false
			RCount = myHero:GetSpellData(_R).level + 2
			Mix:BlockOrb(false)
		end
	end
end

local function CreateObj(obj)
	if obj.team == myHero.team and obj.name == "Xerath_Base_E_mis.troy" then
		EObj = obj
	end

	if obj.team == myHero.team and obj.name:find("Xerath_Base_W_aoe") then
		WObj = obj
	end
end

local function DeleteObj(obj)
	if obj.team == myHero.team and obj.name == "Xerath_Base_E_mis.troy" then
		EObj = nil
	end

	if obj.team == myHero.team and obj.name:find("Xerath_Base_W_aoe") then
		WObj = nil
	end
end


local function KillSteal()
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if Ignite and IsReady(Ignite) and NS_Xe.Ignite.ks:Value() and ValidTarget(enemy, 600) then
			local hp, dmg = Mix:HealthPredict(enemy, 2500, "OW") + enemy.hpRegen*2.5 + enemy.shieldAD, 50 + 20*myHero.level
			if hp > 0 and dmg > hp then CastTargetSpell(enemy, Ignite) end
		end

		local EnemyHP = GetHP2(enemy)
		if Castable[2] and NS_Xe.E.ks:Value() and ManaCheck(NS_Xe.E.MPks:Value()) and EnemyHP < Damage[2](enemy) then
			CastE(enemy)
		end

		if Castable[1] and NS_Xe.W.ks:Value() and ManaCheck(NS_Xe.W.MPks:Value()) and EnemyHP < Damage[1](enemy) then
			CastW(enemy)
		end

		if Castable[0] and NS_Xe.Q.ks:Value() and (ManaCheck(NS_Xe.Q.MPks:Value()) or QActive) and EnemyHP < Damage[0](enemy) then
			CastQ(enemy)
		end
	end
end

local function LaneClear()
	if Castable[1] and NS_Xe.W.lc:Value() and ManaCheck(NS_Xe.W.MPlc:Value()) then
		local WPos, WHit = GetFarmPosition2(Data[1].range, Data[1].width*0.5, Cr.tminion)
		if WHit >= NS_Xe.W.h:Value() then CastSkillShot(_W, WPos) end
	end
	if Castable[0] and NS_Xe.Q.lc:Value() and (ManaCheck(NS_Xe.W.MPlc:Value()) or QActive) then
		local QPos, QHit = GetLineFarmPosition2(QRange[3], Data[0].width, Cr.tminion)
		if not QActive then
			if QHit >= NS_Xe.Q.h:Value() and GetGameTimer() - LastCastTime[1] > 0.1 then
				CastSkillShot(_Q, GetMousePos())
			end
		else
			if GetDistanceSqr(QPos) <= QRange[1]*QRange[1] then
				CastSkillShot2(_Q, QPos)
			end
		end
	end
end

local function JungleClear()
	if not Cr.mmob then return end
	local mob = Cr.mmob
	if Castable[1] and NS_Xe.W.jc:Value() and ManaCheck(NS_Xe.W.MPjc:Value()) then
		CastSkillShot(_W, mob.pos)
	end
	if Castable[2] and NS_Xe.E.jc:Value() and ManaCheck(NS_Xe.E.MPjc:Value()) and ValidTarget(mob, Data[2].range) then
		CastSkillShot(_E, mob.pos)
	end
	if Castable[0] and NS_Xe.Q.jc:Value() and (ManaCheck(NS_Xe.Q.MPjc:Value()) or QActive) then
		if not QActive then
			CastSkillShot(_Q, GetMousePos())
		elseif ValidTarget(mob, QRange[1]) then
			CastSkillShot2(_Q, Vector(mob))
		end
	end
end

local function Escape(WTarget, ETarget)
	Mix:Move()
	if (Castable[1] and WTarget) then
		CastW(WTarget)
		return
	end
	if (Castable[2] and ETarget) then
		CastE(ETarget)
		return
	end
end

local function DrawRange()
	if IsSReady(_Q) then
		Draw[1]:Draw(myHero.pos)
		Draw[5]:Draw(myHero.pos)
	end
	if IsSReady(_W) then Draw[2]:Draw(myHero.pos) end
	if IsSReady(_E) then Draw[3]:Draw(myHero.pos) end
	if NS_Xe.ult.cast.mode:Value() == 3 and RActive then Draw[6]:Draw(GetMousePos()) end
	if IsSReady(_R) then Draw[4]:Draw(myHero.pos) end
end

local function DmgHPBar()
	for i = 1, Enemies.Count, 1 do
		if ValidTarget(Enemies.List[i], Data[3].range) and HPBar[i] then
			HPBar[i]:UpdatePos()
			HPBar[i]:Draw()
		end
	end
end

local function RKillable()
	local d = 0
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		d = d + 1
		if ValidTarget(enemy, Data[3].range) and GetHP2(enemy) < Damage[3](enemy) * RCount then
			DrawText(enemy.charName.." R Killable", 30, GetResolution().x/80, GetResolution().y/7+d*26, GoS.Red)
		end
	end
end

local function DrawRRange()
	if not IsSReady(_R) then return end
	if NS_Xe.dw.Rmm:Value() then DrawCircleMinimap(myHero.pos, Data[3].range, 1, 120, GoS.Cyan) end
end
------------------------------------

local function Tick()
	if myHero.dead then return end
	Updating()
	if RActive then return end
	local QTarget, WTarget, ETarget = nil, nil, nil
	if Castable[0] then QTarget = Target[0]:GetTarget() end
	if Castable[1] then WTarget = Target[1]:GetTarget() end
	if Castable[2] then ETarget = Target[2]:GetTarget() end
	mode = Mix:Mode()
	if mode == "Combo" and CCast then
		if (NS_Xe.misc.castCombo.WE:Value() and (Castable[1] or Castable[2])) or not NS_Xe.misc.castCombo.WE:Value() then
			if NS_Xe.E.cb:Value() and NS_Xe.misc.E:Value() and ETarget then CastE(ETarget) end
			if NS_Xe.W.cb:Value() and WTarget then CastW(WTarget) end
			if NS_Xe.Q.cb:Value() and QTarget then CastQ(QTarget) end
		end
	end

	if mode == "Harass" and CCast then
		if NS_Xe.E.hr:Value() and ManaCheck(NS_Xe.E.MPhr:Value()) and NS_Xe.misc.E:Value() and ETarget then CastE(ETarget) end
		if NS_Xe.W.hr:Value() and ManaCheck(NS_Xe.W.MPhr:Value()) and WTarget then CastW(WTarget) end
		if NS_Xe.Q.hr:Value() and ManaCheck(NS_Xe.Q.MPhr:Value()) and QTarget then CastQ(QTarget) end
	end
	if mode == "Harass" and Castable[0] and QActive and QTarget and not RActive then CastQ(QTarget) end

	if mode == "LaneClear" then
		Cr:Update()
		if CCast or QAcive then
			LaneClear()
			JungleClear()
		end
	end

	KillSteal()

	if NS_Xe.misc.escape:Value() then Escape(WTarget, ETarget) end
end

local function Drawings()
	if myHero.dead then return end
	if NS_Xe.dw.TK:Value() and IsSReady(_R) then RKillable() end
	DmgHPBar()
	DrawRange()
end
------------------------------------

OnLoad(function()
	DrawDmgOnHPBar(NS_Xe.dw, {ARGB(200, 89, 0 ,179), ARGB(200, 0, 245, 255), ARGB(200, 186, 85, 211), ARGB(200, 0, 217, 108)}, {"R", "Q", "W", "E"})
	OnProcessSpellCast(ProcSpellCast)
	OnUpdateBuff(UpdateBuff)
	OnRemoveBuff(RemoveBuff)
	OnCreateObj(CreateObj)
	OnDeleteObj(DeleteObj)
	OnTick(Tick)
	OnDraw(Drawings)
	OnDrawMinimap(DrawRRange)
end)
