--[[ NEETSeries's plugin
	 __   ___   ______    _______   ____  ___      ___       __       __   __  ___ 
	|/"| /  ") /    " \  /" _   "| ))_ ")|"  \    /"  |     /""\     |"  |/  \|  "|
	(: |/   / // ____  \(: ( \___)(____(  \   \  //   |    /    \    |'  /    \:  |
	|    __/ /  /    ) :)\/ \             /\\  \/.    |   /' /\  \   |: /'        |
	(// _  \(: (____/ // //  \ ___       |: \.        |  //  __'  \   \//  /\'    |
	|: | \  \\        / (:   _(  _|      |.  \    /:  | /   /  \\  \  /   /  \\   |
	(__|  \__)\"_____/   \_______)       |___|\__/|___|(___/    \___)|___/    \___|

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

local GetLineFarmPosition2 = function(range, width, objects)
	local Pos, Hit = nil, 0
	for i = 1, #objects, 1 do
		local m = objects[i]
		if ValidTarget(m, range) then
			local count = CountObjectsOnLineSegment(Vector(myHero), Vector(m), width, objects, MINION_ENEMY)
			if not Pos or CountObjectsOnLineSegment(Vector(myHero), Vector(Pos), width, objects, MINION_ENEMY) < count then
				Pos = Vector(m)
				Hit = count
			end
		end
	end
		return {Pos, Hit}
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
	if u ~= myHero or u.dead then return end
	if Check[a] then CCast = true return end
	if a:lower():find("attack") then CCast = false return end
end)

OnProcessSpellAttack(function(u, a)
	if u ~= myHero or u.dead then return end
	if a.name:lower():find("attack") then CCast = false return end
end)

OnProcessSpellComplete(function(u, a)
	if u ~= myHero or u.dead then return end
	if a.name:lower():find("attack") then CCast = true return end
end)
--------------------------------------------------------------------------------

local Data = {
	[0] = { range = myHero:GetSpellData(_Q).range + myHero.boundingRadius,           speed = 1450,      delay = 0.25, width = 140, type = "linear", colNum = 1, slot = 0 },
	[2] = { range = myHero:GetSpellData(_E).range + myHero.boundingRadius,           speed = 1100,      delay = 0.25, width = 240, type = "linear", colNum = 0, slot = 2 },
	[3] = { range = 900 + 300*myHero:GetSpellData(_R).level + myHero.boundingRadius, speed = math.huge, delay = 1,    width = 480, type = "circular", colNum = 0, slot = 3 }
}
local Damage = {
	[0] = function(unit) return CalcDmg(2, unit, 30 + 50*myHero:GetSpellData(_Q).level + 0.5*myHero.ap) end,
	[2] = function(unit) return CalcDmg(2, unit, 15 + 50*myHero:GetSpellData(_E).level + 0.7*myHero.ap) end,
	[3] = function(unit) local bonus = GetPercentHP(unit) < 40 and 2 or (1 + math.min(0.5, math.round((100 - GetPercentHP(unit))*0.83))) return CalcDmg(2, unit, bonus*(60 + 40*myHero:GetSpellData(_R).level + 0.25*myHero.ap + 0.65*myHero.totalDamage)) end
}
local Castable = {
	[0] = false,
	[1] = false,
	[2] = false,
	[3] = false
}

local Cr, WRange, RCount = __MinionManager(Data[2].range, Data[2].range), 0, GotBuff(myHero, "kogmawlivingartillerycost")
local function UpdateDelay(v)
	if v then
		Data[0].delay = 0.125
		Data[2].delay = 0.125
		Data[3].delay = 0.875
		Data[3].delay = 0.875
		Data[3].delay = 0.875
		return
	end
	Data[0].delay = 0.25
	Data[2].delay = 0.25
	Data[3].delay = 1
	Data[3].delay = 1
	Data[3].delay = 1
end

local NS_Kog = MenuConfig("NS_KogMaw", "[NEET Series] - Kog'Maw")

	--[[ Q Settings ]]--
	AddMenu(NS_Kog, "Q", "Q Settings", {true, true, false, true, true, false}, 15)

	--[[ W Settings ]]--
	AddMenu(NS_Kog, "W", "W Settings", {true, false, false, false, false, false})

	--[[ E Settings ]]--
	AddMenu(NS_Kog, "E", "E Settings", {true, true, true, true, true, false}, 15)
	NS_Kog.E:Slider("h", "LaneClear if hit minions >=", 3, 1, 10, 1)

	--[[ Ignite Settings ]]--
	if Ignite then AddMenu(NS_Kog, "Ignite", "Ignite Settings", {false, false, false, false, true, false}) end

		--[[ R Settings ]]--
	AddMenu(NS_Kog, "R", "R Settings", {true, true, false, true, false, false}, 15)
	NS_Kog.R:Boolean("lc", "Use in LaneClear", false)
	NS_Kog.R:Slider("MPlc", "Enable on LaneClear if %MP >=", 15, 1, 100, 1)
	NS_Kog.R:Slider("h", "Use R if hit Minions >=", 3, 1, 10, 1)
	NS_Kog.R:Boolean("ec", "R LaneClear if no enemy in 1200 range", true)
	NS_Kog.R:Boolean("ks", "Use in KillSteal", true)

	--[[ Drawings Menu ]]--
	NS_Kog:Menu("dw", "Drawings Mode")

	--[[ Misc Menu ]]--
	NS_Kog:Menu("misc", "Misc Mode")
		NS_Kog.misc:Menu("rc", "Request Casting R")
			NS_Kog.misc.rc:Boolean("R1", "R but save mana for W", true)
			NS_Kog.misc.rc:Slider("R2", "Cast R if Stacks <=", 5, 1, 10, 1)
			NS_Kog.misc.rc:Slider("R3", "R in Combo if %MP >=", 10, 1, 100, 1)
		NS_Kog.misc:Menu("sme", "Block Move (depend on as)")
			NS_Kog.misc.sme:Info("ifo1", "Dangerous: if distance to enemy <= 300")
			NS_Kog.misc.sme:Info("ifo2", "Kite: if distance to enemy > 600")
			NS_Kog.misc.sme:Info("ifo3", "BlockMove: Other case")
        	NS_Kog.misc.sme:Boolean("b1", "Enable block move check", true)
        	NS_Kog.misc.sme:Slider("b2", "Enable if AttackSpeed >=", 1.7, 1.2, 2.5, 0.1)
			SetSkin(NS_Kog.misc, {"Caterpillar", "Sonoran", "Monarch", "Reindeer", "Lion Dance", "Deep Sea", "Jurassic", "Battlecast", "Disable"})
		LoadPredMenu(NS_Kog)
-----------------------------------

UpdateDelay(GotBuff(myHero, "KogMawBioArcaneBarrage") > 0)
local target = nil
local Target = ChallengerTargetSelector(math.min(Data[0].range, Data[2].range), 1, true, nil, false, NS_Kog)
Target.Menu.TargetSelector.TargetingMode.callback = function(id) Target.Mode = id end

local Draw = {
	[0] = DCircle(NS_Kog.dw, "Q", "Draw Q Range", Data[0].range, ARGB(150, 0, 245, 255)),
	[1] = DCircle(NS_Kog.dw, "W", "Draw W Range", WRange, ARGB(150, 186, 85, 211)),
	[2] = DCircle(NS_Kog.dw, "E", "Draw E Range", Data[2].range, ARGB(150, 0, 217, 108)),
	[3] = DCircle(NS_Kog.dw, "R", "Draw R Range", Data[3].range, ARGB(150, 89, 0 ,179))
}
local Spells = {
	[0] = AddSpell(Data[0], NS_Kog.Q, NS_Kog.cpred:Value()),
	[2] = AddSpell(Data[2], NS_Kog.E, NS_Kog.cpred:Value()),
	[3] = AddSpell(Data[3], NS_Kog.R, NS_Kog.cpred:Value())
}
-----------------------------------

local function CastR(target)
	if not ValidTarget(target, Data[3].range) then return end
		Spells[3]:Cast(target)
end

local function CastE(target)
	if not ValidTarget(target, Data[2].range) then return end
		Spells[2]:Cast(target)
end

local function CastQ(target)
	if not ValidTarget(target, Data[0].range) then return end
		Spells[0]:Cast(target)
end

local function KillSteal()
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if Ignite and IsReady(Ignite) and NS_Kog.Ignite.ks:Value() and ValidTarget(enemy, 600) then
			local hp, dmg = Mix:HealthPredict(enemy, 2500, "OW") + enemy.hpRegen*2.5 + enemy.shieldAD, 50 + 20*myHero.level
			if hp > 0 and dmg > hp then CastTargetSpell(enemy, Ignite) end
		end

		if Castable[0] and NS_Kog.Q.ks:Value() and ManaCheck(NS_Kog.Q.MPks:Value()) and GetHP2(enemy) < Damage[0](enemy) then
			CastQ(enemy)
		end

		if Castable[3] and NS_Kog.R.ks:Value() and GetHP2(enemy) < Damage[3](enemy) then
			CastR(enemy)
		end

		if Castable[2] and NS_Kog.E.ks:Value() and ManaCheck(NS_Kog.E.MPks:Value()) and GetHP2(enemy) < Damage[2](enemy) then
			CastE(enemy)
		end
	end
end

local function LaneClear()
	if Castable[3] and NS_Kog.R.lc:Value() and ManaCheck(NS_Kog.R.MPlc:Value()) then
		if RCount > NS_Kog.misc.rc.R2:Value() then return end
		if NS_Kog.R.ec:Value() and EnemiesAround(myHero.pos, 1200) > 0 then return end
		if NS_Kog.misc.rc.R1:Value() and myHero.mana - 40*RCount < 40 then return end
		local Farm = GetFarmPosition2(Data[3].range, Data[3].width, Cr.tminion)
		if Farm[2] >= NS_Kog.R.h:Value() then CastSkillShot(_R, Farm[1]) end
    end
    if Castable[2] and NS_Kog.E.lc:Value() and ManaCheck(NS_Kog.E.MPlc:Value()) then
    	local Farm = GetLineFarmPosition2(Data[2].range, Data[2].width, Cr.tminion)
		if Farm[2] >= NS_Kog.E.h:Value() then CastSkillShot(_E, Farm[1]) end
	end
end

local function JungleClear()
	if not Cr.mmob then return end
	local mob = Cr.mmob
	if Castable[0] and NS_Kog.Q.jc:Value() and ManaCheck(NS_Kog.Q.MPjc:Value()) and ValidTarget(mob, Data[0].range) then
		CastSkillShot(_Q, mob.pos)
	end
	if Castable[2] and NS_Kog.E.jc:Value() and ManaCheck(NS_Kog.E.MPjc:Value()) then
		CastSkillShot(_E, mob.pos)
	end
	if Castable[3] and NS_Kog.R.jc:Value() and ManaCheck(NS_Kog.R.MPjc:Value()) and ValidTarget(mob, Data[3].range) and RCount <= NS_Kog.misc.rc.R2:Value() and ((NS_Kog.misc.rc.R1:Value() and myHero.mana - 40*RCount > 40) or not NS_Kog.misc.rc.R1:Value()) then
		CastSkillShot(_R, mob.pos)
	end
end

local function DrawRange()
	local myPos = myHero.pos
	if IsSReady(_Q) then Draw[0]:Draw(myPos) end
	if IsSReady(_W) then Draw[1]:Draw(myPos) end
	if IsSReady(_E) then Draw[2]:Draw(myPos) end
	if IsSReady(_R) then Draw[3]:Draw(myPos) end
end

local function DmgHPBar()
	for i = 1, Enemies.Count, 1 do
		if ValidTarget(Enemies.List[i], Data[3].range*2) and HPBar[i] then
			HPBar[i]:UpdatePos()
			HPBar[i]:Draw()
		end
	end
end

local function Updating()
	Castable[0] = IsReady(0);
	Castable[1] = IsReady(1);
	Castable[2] = IsReady(2);
	Castable[3] = IsReady(3);
	WRange = 675 + 20*myHero:GetSpellData(_W).level
	Data[3].range = 900 + 300*myHero:GetSpellData(3).level + myHero.boundingRadius
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if ValidTarget(enemy, Data[3].range*2) and HPBar[i] then
			HPBar[i]:SetValue(1, Damage[3](enemy), IsSReady(_R))
			HPBar[i]:SetValue(2, Damage[0](enemy), IsSReady(_Q))
			HPBar[i]:SetValue(3, Damage[2](enemy), IsSReady(_E))
			HPBar[i]:CheckValue()
		end
	end

	if Castable[1] then Draw[1]:Update("range", WRange) end
	if Castable[3] then Draw[3]:Update("range", Data[3].range) end
	target = Target:GetTarget()
end

local function GetRTarget()
	local RTarget = nil
	for i = 1, Enemies.Count, 1 do
		local enemy = Enemies.List[i]
		if ValidTarget(enemy, Data[3].range) then
			if not RTarget or GetHP2(enemy) - Damage[3](enemy) < GetHP2(RTarget) - Damage[3](RTarget) then
				RTarget = enemy
			end
		end
	end
		return RTarget
end

local function UpdateBuff(unit, buff)
	if unit == myHero then
		if buff.Name:lower() == "kogmawlivingartillerycost" then RCount = buff.Count end
		if buff.Name:lower() == "kogmawbioarcanebarrage" then
			UpdateDelay(true)
		end
	end
end

local function RemoveBuff(unit, buff)
	if unit == myHero then
		if buff.Name:lower() == "kogmawlivingartillerycost" then RCount = 1 end
		if buff.Name:lower() == "kogmawbioarcanebarrage" then
			UpdateDelay(false)
		end
    end
end

---------------------------------------------
local function Tick()
	if myHero.dead then return end
	Updating()
	mode = Mix:Mode()
	Mix:ForceTarget(target)

	if target and mode == "Combo" and EnemiesAround(myHero.pos, 300) > 0 and NS_Kog.misc.sme.b1:Value() and 0.625*myHero.attackSpeed >= NS_Kog.misc.sme.b2:Value() then
		Mix:BlockMovement(true)
	else
		Mix:BlockMovement(false)
	end

	if mode == "Combo" and CCast then
		if Castable[2] and NS_Kog.E.cb:Value() then CastE(target) end
		if Castable[1] and NS_Kog.W.cb:Value() and ValidTarget(target, WRange - 80) then CastSpell(1) end
		if Castable[0] and NS_Kog.Q.cb:Value() then CastQ(target) end
		if Castable[3] and NS_Kog.R.cb:Value() and ManaCheck(NS_Kog.misc.rc.R3:Value()) and RCount <= NS_Kog.misc.rc.R2:Value() and ((NS_Kog.misc.rc.R1:Value() and myHero.mana - 40*RCount >= 40) or not NS_Kog.misc.rc.R1:Value()) then CastR(GetRTarget()) end
	end

    if mode == "Harass" and CCast then
		if Castable[2] and NS_Kog.E.hr:Value() and ManaCheck(NS_Kog.E.MPhr:Value()) then CastE(target) end
		if Castable[0] and NS_Kog.Q.hr:Value() and ManaCheck(NS_Kog.Q.MPhr:Value()) then CastE(target) end
		if Castable[3] and NS_Kog.R.hr:Value() and ManaCheck(NS_Kog.R.MPhr:Value()) and RCount <= NS_Kog.misc.rc.R2:Value() and ((NS_Kog.misc.rc.R1:Value() and myHero.mana - 40*RCount >= 40) or not NS_Kog.misc.rc.R1:Value()) then CastR(GetRTarget()) end
	end

	if mode == "LaneClear" then
		Cr:Update()
		if CCast then
			LaneClear()
			JungleClear()
		end
	end

	KillSteal()
end

local function Drawings()
	if myHero.dead then return end
	DmgHPBar()
	DrawRange()
end
------------------------------------

OnLoad(function()
	DrawDmgOnHPBar(NS_Kog.dw, {ARGB(200, 89, 0 ,179), ARGB(200, 0, 245, 255), ARGB(200, 0, 217, 108)}, {"R", "Q", "E"})
	OnUpdateBuff(UpdateBuff)
	OnRemoveBuff(RemoveBuff)
	OnTick(Tick)
	OnDraw(Drawings)
end)
