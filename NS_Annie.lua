--[[ NEETSeries's plugin
	      __      _____  ___   _____  ___    __     _______  
	     /""\    (\"   \|"  \ (\"   \|"  \  |" \   /"     "| 
	    /    \   |.\\   \    ||.\\   \    | ||  | (: ______) 
	   /' /\  \  |: \.   \\  ||: \.   \\  | |:  |  \/    |   
	  //  __'  \ |.  \    \. ||.  \    \. | |.  |  // ___)_  
	 /   /  \\  \|    \    \ ||    \    \ | /\  |\(:      "| 
	(___/    \___)\___|\____\) \___|\____\)(__\_|_)\_______) 

---------------------------------------]]
local Enemies, HPBar, CCast, mode = LoadEnemies(), { }, false, ""
local huge, max, min = math.huge, math.max, math.min
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

local GetFarmPosition2 = function(range, width, objects)
	local Pos, Hit = nil, 0
	for i = 1, #objects, 1 do
		local m = objects[i]
		if ValidTarget(m, range) then
			local count = CountObjectsNearPos(Vector(m), nil, width, objects, MINION_ENEMY)
			if not Pos or CountObjectsNearPos(Vector(Pos), nil, width, objects, MINION_ENEMY) < count then
				Pos = Vector(m)
				Hit = count
			end
		end
	end
		return {Pos, Hit}
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

local Q = { range = myHero:GetSpellData(_Q).range, speed = 1500, delay = 250 }
local W = { range = myHero:GetSpellData(_W).range, speed = huge, delay = 0.25, width = 80, type = "cone", slot = 1, colNum = 0, angle = 50 }
local R = { range = myHero:GetSpellData(_R).range, speed = huge, delay = 0.25, width = 500, type = "circular", slot = 3, colNum = 0 }
local D = { Flash = MixLib:GetSlotByName("summonerflash", 4, 5), passive = GotBuff(myHero, "pyromania"), stun = GotBuff(myHero, "pyromania_particle") > 0, Teddy = GotBuff(myHero, "infernalguardiantimer") > 0 }
local Cr = __MinionManager(Q.range, Q.range)
local Damage = {
	[0] = function(unit) return CalcDmg(2, unit, 45 + 35*myHero:GetSpellData(_Q).level + 0.8*myHero.ap) end,
	[1] = function(unit) return CalcDmg(2, unit, 25 + 45*myHero:GetSpellData(_W).level + 0.85*myHero.ap) end,
	[3] = function(unit) return CalcDmg(2, unit, 25 + 130*myHero:GetSpellData(_R).level + 0.7*myHero.ap) end
}
local Castable = {
	[0] = false,
	[1] = false,
	[2] = false,
	[3] = false
}

local NS_Annie = MenuConfig("NS_Annie", "[NEET Series] - Annie")

	--[[ Q Settings ]]--
	AddMenu(NS_Annie, "Q", "Q Settings", {true, true, true, true, true, true}, 15)
	NS_Annie.Q:Boolean("s1", "Harass but save stun", true)
	NS_Annie.Q:Boolean("s2", "LaneClear but save stun", true)
	NS_Annie.Q:Boolean("s3", "LastHit but save stun", false)

	--[[ W Settings ]]--
	AddMenu(NS_Annie, "W", "W Settings", {true, true, false, true, true, false}, 15)
	NS_Annie.W:Boolean("s", "Harass but save stun", true)

	--[[ E Settings ]]--
	AddMenu(NS_Annie, "E", "E Settings", {true, false, false, false, false, false})

	--[[ Ignite Settings ]]--
	if Ignite then AddMenu(NS_Annie, "Ignite", "Ignite Settings", {false, false, false, false, true, false}) end

	--[[ Ultimate Menu ]]--
	NS_Annie:Menu("ult", "Ultimate Settings")
		NS_Annie.ult:DropDown("u1", "Casting Mode", 1, {"If Killable", "If can stun x enemies"})
		NS_Annie.ult:Slider("u2", "R if can stun enemies >=", 2, 1, 5, 1)
		NS_Annie.ult:KeyBinding("u3", "Use R if Combo Active (G)", 71, true)
	if D.Flash ~= nil then
		NS_Annie.ult:Menu("fult", "Flash and Ultimate")
			NS_Annie.ult.fult:Boolean("eb1", "Enable?", false)
			NS_Annie.ult.fult:DropDown("eb2", "Active Mode: ", 1, {"Use when Combo Active", "Auto Use"})
			NS_Annie.ult.fult:Slider("x1", "If can stun x enemy", 3, 1, 5, 1)
			NS_Annie.ult.fult:Slider("x2", "If ally around >=", 1, 0, 5, 1)
	end

	--[[ Drawings Menu ]]--
	NS_Annie:Menu("dw", "Drawings Mode")
		NS_Annie.dw:Menu("lh", "Draw Q LastHit Circle")
		NS_Annie.dw.lh:Boolean("e", "Enable", true)
		NS_Annie.dw.lh:ColorPick("c1", "Color if QDmg*2.5 can kill", {200, 255, 191, 0})
		NS_Annie.dw.lh:ColorPick("c2", "Color if QDmg can kill", {200, 255, 0, 0})

	--[[ Misc Menu ]]--
	NS_Annie:Menu("misc", "Misc Mode")  
		NS_Annie.misc:Menu("E", "E Setting")
		NS_Annie.misc.E:KeyBinding("eb1", "Auto E update stack (Z)", 90, true)
		NS_Annie.misc.E:Slider("eb2", "Auto E if %MP > ", 50, 1, 100, 1)
		NS_Annie.misc.E:Boolean("eb3", "Auto E if need 1 stack to stun", true)
		SetSkin(NS_Annie.misc, {"Goth", "Red Riding", "Wonderland", "Prom Queen", "Frostfire", "Reverse", "FrankenTibbers", "Panda", "Sweetheart", "Hextech", "Disable"})
	LoadPredMenu(NS_Annie)
	PermaShow(NS_Annie.ult.u3)
	PermaShow(NS_Annie.misc.E.eb1)
-----------------------------------

local Spell = {
	[1] = AddSpell(W, NS_Annie.W, NS_Annie.cpred:Value()),
	[3] = AddSpell(R, NS_Annie.ult, NS_Annie.cpred:Value())
}
local Target = {
	[0] = ChallengerTargetSelector(Q.range, 2, false, nil, false, NS_Annie.Q),
	[1] = ChallengerTargetSelector(W.range, 2, false, nil, false, NS_Annie.W),
	[3] = ChallengerTargetSelector(R.range, 2, true, nil, false, NS_Annie.ult)
}
local Draw = {
	[0] = DCircle(NS_Annie.dw, "Q", "Draw Q Range", Q.range, ARGB(150, 0, 245, 255)),
	[1] = DCircle(NS_Annie.dw, "W", "Draw W Range", W.range, ARGB(150, 186, 85, 211)),
	[3] = DCircle(NS_Annie.dw, "R", "Draw R Range", R.range, ARGB(150, 89, 0 ,179))
}

Target[0].Menu.TargetSelector.TargetingMode.callback = function(id) Target[0].Mode = id end
Target[1].Menu.TargetSelector.TargetingMode.callback = function(id) Target[1].Mode = id end
Target[3].Menu.TargetSelector.TargetingMode.callback = function(id) Target[3].Mode = id end
ChallengerAntiGapcloser(NS_Annie.misc, function(o, s) if not D.stun then return end if ValidTarget(o, W.range) and Castable[1] then Spell[1]:Cast(o) elseif ValidTarget(o, Q.range) and Castable[0] then CastTargetSpell(o, _Q) end end)
ChallengerInterrupter(NS_Annie.misc, function(o, s) if not D.stun then return end if ValidTarget(o, W.range) and Castable[1] then Spell[1]:Cast(o) elseif ValidTarget(o, Q.range) and Castable[0] then CastTargetSpell(o, _Q) end end)
-----------------------------------

local function CastR(target)
	if not ValidTarget(target, R.range) then return end
		Spell[3]:Cast(target)
end

local function CastQ(target)
	if not ValidTarget(target, Q.range) then return end
		CastTargetSpell(target, _Q)
end

local function CastW(target)
	if not ValidTarget(target, W.range) then return end
		Spell[1]:Cast(target)
end

local function FlashR()
	if EnemiesAround(myHero.pos, R.range) == 0 and EnemiesAround(myHero.pos, R.range + 420) > 0 and AlliesAround(myHero.pos, R.range) >= NS_Annie.ult.fult.x2:Value() then
		local pred = GetFarmPosition2(R.width, R.range + 420, Enemies)
		if pred[2] >= NS_Annie.ult.fult.x1:Value() then
			CastSkillShot(D.Flash, pred[1])
			if GetDistance(pred[1]) <= R.range then CastSkillShot(_R, pred[1]) end
		end
	end
end

local function CheckR()
	if NS_Annie.ult.u1:Value() == 1 then
		local target = Target[3]:GetTarget()
		if ValidTarget(target, R.range) and GetHP2(target) < Damage[3](target) and (not Castable[0] or (Castable[0] and ValidTarget(target, Q.range) and GetHP2(target) > Damage[0](target))) and (not Castable[1] or (Castable[1] and ValidTarget(target, W.range) and GetHP2(target) > Damage[1](target))) then CastR(target) end
	else
		local pred = GetFarmPosition2(R.width, R.range, Enemies)
		if pred[2] >= NS_Annie.ult.u2:Value() then CastSkillShot(_R, pred[1]) end
	end
end

local function KillSteal()
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if Ignite and IsReady(Ignite) and NS_Annie.Ignite.ks:Value() and ValidTarget(enemy, 600) then
			local hp, dmg = Mix:HealthPredict(enemy, 2500, "OW") + enemy.hpRegen*2.5 + enemy.shieldAD, 50 + 20*myHero.level
			if hp > 0 and dmg > hp then CastTargetSpell(enemy, Ignite) end
		end

		if Castable[1] and NS_Annie.W.ks:Value() and ManaCheck(NS_Annie.W.MPks:Value()) and ValidTarget(enemy, W.range) and GetHP2(enemy) < Damage[1](enemy) then 
			CastW(enemy)
		elseif Castable[0] and NS_Annie.Q.ks:Value() and ManaCheck(NS_Annie.Q.MPks:Value()) and ValidTarget(enemy, Q.range) and GetHP2(enemy) < Damage[0](enemy) then 
			CastQ(enemy)
		end
	end
end

local function JungleClear()
	if not Cr.mmob then return end
	local mob = Cr.mmob
	if Castable[1] and NS_Annie.W.jc:Value() and ManaCheck(NS_Annie.W.MPjc:Value()) and ValidTarget(mob, W.range) then
		CastSkillShot(_W, mob.pos)
	end
	if Castable[0] and NS_Annie.Q.jc:Value() and ManaCheck(NS_Annie.Q.MPjc:Value()) and ValidTarget(mob, Q.range) then
		CastTargetSpell(mob, _Q)
	end
end

local function QFarmAndDraw()
	for i = 1, #Cr.tminion, 1 do
		local minion = Cr.tminion[i]
		local HPPred = Mix:HealthPredict(minion, Q.delay + GetDistanceSqr(minion)/Q.speed, "OW")
		local Pos = minion.pos
		if HPPred > 0 and Damage[0](minion) > HPPred then
			if NS_Annie.dw.lh.e:Value() then DrawCircle3D(Pos.x, Pos.y, Pos.z, 50, 1, NS_Annie.dw.lh.c2:Value(), 20) end
			if (mode == "LastHit" and ManaCheck(NS_Annie.Q.MPlh:Value()) and ((NS_Annie.Q.s3:Value() and not D.stun) or not NS_Annie.Q.s3:Value())) or (mode == "LaneClear" and ManaCheck(NS_Annie.Q.MPlc:Value()) and ((NS_Annie.Q.s2:Value() and not D.stun) or not NS_Annie.Q.s2:Value())) then
				CastTargetSpell(minion, _Q)
			end
		elseif Damage[0](minion)*2.5 > minion.health and NS_Annie.dw.lh.e:Value() then
			DrawCircle3D(Pos.x, Pos.y, Pos.z, 50, 1, NS_Annie.dw.lh.c1:Value(), 20)
		end
	end
end

local function DrawRange()
	local myPos = myHero.pos
	if IsSReady(_Q) then Draw[0]:Draw(myPos) end
	if IsSReady(_W) then Draw[1]:Draw(myPos) end
	if IsSReady(_R) then Draw[3]:Draw(myPos) end
end

local function DmgHPBar()
	for i = 1, Enemies.Count, 1 do
		if ValidTarget(Enemies.List[i], 1500) and HPBar[i] then
			HPBar[i]:UpdatePos()
			HPBar[i]:Draw()
		end
	end
end

local function UseE(unit, spell)
	if mode == "Combo" and NS_Annie.E.cb:Value() and unit.type == "AIHeroClient" and unit.team == MINION_ENEMY then
		if spell.target == myHero and Castable[2] then
			CastSpell(_E)
		end
	end
end

local function CheckSpell(unit, spell)
	if unit == myHero and spell.name:lower() == "disintegrate" and D.passive == 3 and spell.target.type == "AIHeroClient" and Castable[2] then
		CastSpell(_E)
	end
end

local function UpdateBuff(unit, buff)
	if unit == myHero then
		if buff.Name == "pyromania" then D.passive = buff.Count end
		if buff.Name == "pyromania_particle" then D.stun = true end
		if buff.Name == "infernalguardiantimer" then D.Teddy = true end
	end
end

local function RemoveBuff(unit, buff)
	if unit == myHero then
		if buff.Name == "pyromania" then D.passive = 0 end
		if buff.Name == "pyromania_particle" then D.stun = false end
		if buff.Name == "infernalguardiantimer" then D.Teddy = false end
	end
end
------------------------------------

local function Tick()
	if myHero.dead then return end
	Castable[0] = IsReady(0);
	Castable[1] = IsReady(1);
	Castable[2] = IsReady(2);
	Castable[3] = IsReady(3);
	local QTarget = Castable[0] and Target[0]:GetTarget()
	local WTarget = Castable[1] and Target[1]:GetTarget()
	mode = Mix:Mode()
	if mode == "Combo" and CCast then
		if Castable[0] and NS_Annie.Q.cb:Value() then CastQ(QTarget) end
		if Castable[1] and NS_Annie.W.cb:Value() then CastW(WTarget) end
    end

    if Castable[3] and not D.Teddy then
    	local cbON = NS_Annie.ult.u3:Value()
		if (cbON and mode == "Combo" and CCast) or not cbON then CheckR() end
		if D.Flash and IsReady(D.Flash) and Castable[3] and NS_Annie.ult.fult.eb1:Value() and ((NS_Annie.ult.fult.eb2:Value() == 1 and mode == "Combo") or NS_Annie.ult.fult.eb2:Value() == 2) then FlashR() end
    end

    if Castable[2] and NS_Annie.misc.E.eb1:Value() and ManaCheck(NS_Annie.misc.E.eb2:Value()) and EnemiesAround(myHero.pos, 1500) == 0 and not D.stun then CastSpell(_E) end

    if mode == "Harass" and CCast then
		if Castable[0] and NS_Annie.Q.hr:Value() and ManaCheck(NS_Annie.Q.MPhr:Value()) and ((NS_Annie.Q.s1:Value() and not D.stun) or not NS_Annie.Q.s1:Value()) then CastQ(QTarget) end
		if Castable[1] and NS_Annie.W.hr:Value() and ManaCheck(NS_Annie.W.MPhr:Value()) and ((NS_Annie.W.s:Value() and not D.stun) or not NS_Annie.W.s:Value()) then CastW(WTarget) end
    end

    if mode == "LaneClear" and CCast then
		JungleClear()
    end

	KillSteal()

	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if ValidTarget(enemy, 1500) and HPBar[i] then
			HPBar[i]:SetValue(1, Damage[3](enemy), IsSReady(_R))
			HPBar[i]:SetValue(2, Damage[0](enemy), IsSReady(_Q))
			HPBar[i]:SetValue(3, Damage[1](enemy), IsSReady(_W))
			HPBar[i]:CheckValue()
		end
	end
end

local function Drawings()
	if myHero.dead then return end
	DmgHPBar()
	DrawRange()
	if mode == "LaneClear" or mode == "LastHit" then
		Cr:Update()
		if Castable[0] then QFarmAndDraw() end
	end
end
------------------------------------

OnLoad(function()
	DrawDmgOnHPBar(NS_Annie.dw, {ARGB(200, 89, 0 ,179), ARGB(200, 0, 245, 255), ARGB(200, 0, 217, 108)}, {"R", "Q", "W"})
	OnProcessSpellCast(CheckSpell)
	OnProcessSpellComplete(UseE)
	OnUpdateBuff(UpdateBuff)
	OnRemoveBuff(RemoveBuff)
	OnTick(Tick)
	OnDraw(Drawings)
end)
