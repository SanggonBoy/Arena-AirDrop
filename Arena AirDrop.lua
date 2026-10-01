-- ARENA AIRDROP v1 - HUD + tab Tempur
-- PlaceId: 93091759101123 | "FPS Arena AirDrop [S4]" (Havoc Warfare, v11304)
-- Struktur game (terverifikasi live 2026-09-29):
--   Workspace: GuideFolder, Area, MonsterFolder, SkillFloder, WeaponFloder,
--              DropItemFloder, ShowScene (dummy latih + teleporter), GlobalFlag
--   ReplicatedStorage: 1 RemoteEvent "Main" (semua aksi lewat 1 channel),
--              Asset.Prefabs (Tools/Gun/Gloves/ViewModels 339), Sound
--   PlayerGui game: LobbyMain, BattleMain, BattleSet, BattleInfo, ReticleGui,
--              NormalDrop, Rescue, Summary, SpectatorMode, SignIn
-- WalkSpeed asli 30, JumpPower 50, 7 pemain, tanpa tim (FFA).
-- Toggle: Insert / RightShift / tombol AAD. Semua default OFF, tidak menulis
-- gerakan sebelum user menyentuh slider (pola anti-flicker + anti dobel-jalan).
-- GUARD: queue_on_teleport Xeno GLOBAL → file bisa dieksekusi di game lain.
-- PlaceId resmi 93091759101123 (diizinkan juga universe 10031505426 bila pindah place).
if game.PlaceId~=93091759101123 and game.GameId~=10031505426 then
	warn('[AAD] Dilewati: cheat ini untuk Arena AirDrop, bukan game lain (place '..tostring(game.PlaceId)..')')
	return
end

local Players=game:GetService('Players')
local RS=game:GetService('ReplicatedStorage')
local RunService=game:GetService('RunService')
local Lighting=game:GetService('Lighting')
local UIS=game:GetService('UserInputService')
local Workspace=game:GetService('Workspace')
local TeleportService=game:GetService('TeleportService')

local lp=Players.LocalPlayer
local pg=lp:WaitForChild('PlayerGui')

local old=pg:FindFirstChild('AAD_HUD')
if old then old:Destroy() end

-- Generasi anti dobel-jalan
local ENV=(function()
	local ok,g=pcall(function() return getgenv() end)
	if ok and g then return g end
	return _G
end)()
ENV.AAD_GEN=(ENV.AAD_GEN or 0)+1
local MYGEN=ENV.AAD_GEN
local function alive() return MYGEN==ENV.AAD_GEN end

-- ================= STATE (session-local, tidak otomatis) =================
local S={
	espP=false, espC=false, fb=false,
	fly=false, flySpd=70, nc=false, ij=false, afk=false,
	-- combat
	aim=false, aimADS=false, aimVis=true, aimHead=true, aimNPC=false,
	aimFov=140, aimSmooth=8, fovShow=true, bigHead=false, headSize=3,
	noSpread=false,
	trig=false, trigDelay=120,
	espM=false, espB=false,
	magnetOrb=false, magnetRange=60,
	cfgAuto=false, -- auto-load konfigurasi tersimpan saat script jalan/teleport
}
local SavedWS, SavedJP = 30, 50 -- WS asli game ini 30 (terverifikasi live)
local SpeedDirty, JumpDirty = false, false
local SavedPos = nil
-- headOrig DIKONGSI antar reload (getgenv) supaya ukuran asli tidak pernah
-- ikut terkompensasi saat file dieksekusi ulang (bug: kepala 3x lipat).
ENV.AAD_HEADS=ENV.AAD_HEADS or {}
local headOrig=ENV.AAD_HEADS
local applyBigHead,restoreHeads
local hookNoSpread,unhookNoSpread
local function applyStats()
	local c=lp.Character
	if not c then return end
	local h=c:FindFirstChildOfClass('Humanoid')
	if not h then return end
	if SpeedDirty then pcall(function() h.WalkSpeed=SavedWS end) end
	if JumpDirty then pcall(function() if not h.UseJumpPower then h.UseJumpPower=true end h.JumpPower=SavedJP end) end
end
lp.CharacterAdded:Connect(function(c)
	pcall(function() c:WaitForChild('Humanoid',5) end)
	task.wait(0.5)
	pcall(applyStats)
end)
local oFB={Lighting.Brightness,Lighting.Ambient,Lighting.OutdoorAmbient,Lighting.ClockTime,Lighting.GlobalShadows}
local espReg={}
local cleanupCombat=function() end
-- Sapu Drawing sisa eksekusi file sebelumnya (Drawing tidak ikut hancur saat GUI di-destroy)
pcall(function()
	local b=ENV.AAD_BONES
	if b then for _,l in ipairs(b) do pcall(function() l:Remove() end) end end
	ENV.AAD_BONES={}
	if ENV.AAD_FOV then pcall(function() ENV.AAD_FOV:Remove() end) ENV.AAD_FOV=nil end
end)

-- ================= UTIL =================
local function mk(c,pr,p)
	local o=Instance.new(c)
	for k,v in pairs(pr) do o[k]=v end
	o.Parent=p
	return o
end
local function cr(p,r)
	mk('UICorner',{CornerRadius=UDim.new(0,r or 8)},p)
	return p
end
local function log(t) print('[AAD] '..tostring(t)) end

-- ================= FRAME =================
local gui=mk('ScreenGui',{Name='AAD_HUD',ResetOnSpawn=false,ZIndexBehavior=Enum.ZIndexBehavior.Sibling,DisplayOrder=2000},pg)
local main=mk('Frame',{Name='Main',AnchorPoint=Vector2.new(0.5,0.5),Size=UDim2.new(0,560,0,400),Position=UDim2.new(0.5,0,0.5,0),BackgroundColor3=Color3.fromRGB(16,18,24),BorderSizePixel=0,Active=true},gui)
cr(main,12)
mk('UIStroke',{Color=Color3.fromRGB(60,110,180),Thickness=1.2},main)
-- Watermark pembuat (pojok kanan-bawah, non-interaktif); ikut sembunyi bersama HUD
local wm=mk('TextLabel',{Size=UDim2.new(0,240,0,16),Position=UDim2.new(1,-252,1,-22),
	BackgroundTransparency=1,Text='by Alexander Jay · @absrdme',Font=Enum.Font.Gotham,
	TextSize=11,TextColor3=Color3.fromRGB(150,160,180),TextTransparency=0.35,
	TextXAlignment=Enum.TextXAlignment.Right,Active=false,ZIndex=1},gui)

local float=mk('TextButton',{Text='AAD',Font=Enum.Font.GothamBold,TextSize=16,TextColor3=Color3.fromRGB(255,255,255),Size=UDim2.new(0,52,0,52),Position=UDim2.new(0,12,0.5,-26),BackgroundColor3=Color3.fromRGB(45,90,160),BorderSizePixel=0,Active=true,AutoButtonColor=true},gui)
cr(float,26)
mk('UIStroke',{Color=Color3.fromRGB(120,180,255),Thickness=2},float)
do
	local dg,sp,si,mvd=false,nil,nil,0
	float.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then
			dg=true mvd=0 sp=float.Position si=io.Position
		end
	end)
	float.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then dg=false end
	end)
	UIS.InputChanged:Connect(function(io)
		if dg and sp and si and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then
			local d=io.Position-si
			mvd=mvd+math.abs(d.X)+math.abs(d.Y)
			float.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
		end
	end)
	float.MouseButton1Click:Connect(function() if mvd<8 and ENV.AAD_GEN==MYGEN then main.Visible=not main.Visible wm.Visible=main.Visible setCursorFree(main.Visible) end end)
end

local tb=mk('Frame',{Size=UDim2.new(1,0,0,38),BackgroundColor3=Color3.fromRGB(24,28,38),BorderSizePixel=0},main)
cr(tb,12)
mk('TextLabel',{BackgroundTransparency=1,Position=UDim2.new(0,14,0,0),Size=UDim2.new(0.85,0,1,0),Text='🔫 ARENA AIRDROP v1 · by Alexander Jay (@absrdme)',Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(120,180,255),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},tb)
local bHide=mk('TextButton',{Position=UDim2.new(1,-40,0,7),Size=UDim2.new(0,30,0,24),Text='–',Font=Enum.Font.GothamBold,TextSize=18,TextColor3=Color3.fromRGB(220,220,230),BackgroundColor3=Color3.fromRGB(38,44,58),BorderSizePixel=0},tb)
cr(bHide,6)
-- Buka HUD = cursor dibebaskan (game shooter mengunci mouse);
-- tutup HUD = kunci lagi. Plus tombol manual di tab Lain.
local CursorFree=false
local SavedBehavior=nil
local function setCursorFree(on)
	CursorFree=on
	pcall(function()
		if on then
			SavedBehavior=UIS.MouseBehavior
			UIS.MouseBehavior=Enum.MouseBehavior.Default
		elseif SavedBehavior then
			UIS.MouseBehavior=SavedBehavior
		else
			UIS.MouseBehavior=Enum.MouseBehavior.LockedCenter
		end
	end)
end
bHide.MouseButton1Click:Connect(function() main.Visible=false wm.Visible=false setCursorFree(false) end)
do
	local dg,sp,si=false,nil,nil
	tb.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then
			dg=true sp=main.Position si=io.Position
		end
	end)
	tb.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then dg=false end
	end)
	UIS.InputChanged:Connect(function(io)
		if dg and sp and si and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then
			local d=io.Position-si
			main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
		end
	end)
end

-- ================= WIDGETS =================
local ord=0
local togPainters={}
local togCbs={}
local slideRegs={}
local function sect(page,txt)
	ord=ord+1
	mk('TextLabel',{Size=UDim2.new(1,-4,0,20),BackgroundTransparency=1,Text=txt,Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(120,180,255),TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=ord},page)
end
local function tog(page,txt,key,cb)
	ord=ord+1
	local b=mk('TextButton',{Size=UDim2.new(1,-4,0,34),BackgroundColor3=Color3.fromRGB(28,33,44),Text='',Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(215,210,205),TextXAlignment=Enum.TextXAlignment.Left,BorderSizePixel=0,LayoutOrder=ord},page)
	mk('UIPadding',{PaddingLeft=UDim.new(0,12)},b)
	cr(b,8)
	local function paint()
		local on=S[key]
		b.Text=txt..'      '..(on and '● ON' or '○ OFF')
		b.BackgroundColor3=on and Color3.fromRGB(40,85,150) or Color3.fromRGB(28,33,44)
	end
	paint()
	togPainters[key]=togPainters[key] or {}
	table.insert(togPainters[key],paint)
	if cb then togCbs[key]=cb end
	b.MouseButton1Click:Connect(function()
		S[key]=not S[key]
		paint()
		if cb then cb(S[key]) end
	end)
	return b
end
local function btn(page,txt,cb)
	ord=ord+1
	local b=mk('TextButton',{Size=UDim2.new(1,-4,0,34),BackgroundColor3=Color3.fromRGB(45,60,85),Text=txt,Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(235,230,225),BorderSizePixel=0,LayoutOrder=ord},page)
	cr(b,8)
	b.MouseButton1Click:Connect(function()
		task.spawn(function() pcall(cb) end)
	end)
	return b
end
local function slide(page,txt,min,max,def,cb,key)
	ord=ord+1
	local f=mk('Frame',{Size=UDim2.new(1,-4,0,48),BackgroundColor3=Color3.fromRGB(24,28,38),BorderSizePixel=0,LayoutOrder=ord},page)
	cr(f,8)
	mk('TextLabel',{BackgroundTransparency=1,Position=UDim2.new(0,12,0,4),Size=UDim2.new(0.6,0,0,16),Text=txt,Font=Enum.Font.Gotham,TextSize=12,TextColor3=Color3.fromRGB(205,200,195),TextXAlignment=Enum.TextXAlignment.Left},f)
	local val=mk('TextLabel',{BackgroundTransparency=1,Position=UDim2.new(1,-62,0,4),Size=UDim2.new(0,50,0,16),Text=tostring(def),Font=Enum.Font.GothamBold,TextSize=12,TextColor3=Color3.fromRGB(140,190,255),TextXAlignment=Enum.TextXAlignment.Right},f)
	local bar=mk('Frame',{Position=UDim2.new(0,12,0,28),Size=UDim2.new(1,-24,0,6),BackgroundColor3=Color3.fromRGB(50,58,75),BorderSizePixel=0},f)
	cr(bar,3)
	local fill=mk('Frame',{Size=UDim2.new((def-min)/math.max(max-min,1),0,1,0),BackgroundColor3=Color3.fromRGB(80,140,230),BorderSizePixel=0},bar)
	cr(fill,3)
	local hold=false
	local function set(x)
		local rel=math.clamp((x-bar.AbsolutePosition.X)/math.max(bar.AbsoluteSize.X,1),0,1)
		local v=math.floor(min+(max-min)*rel+0.5)
		val.Text=tostring(v)
		fill.Size=UDim2.new(rel,0,1,0)
		cb(v)
	end
	local function setVal(v)
		v=math.clamp(math.floor(v+0.5),min,max)
		local rel=(v-min)/math.max(max-min,1)
		val.Text=tostring(v)
		fill.Size=UDim2.new(rel,0,1,0)
		cb(v)
	end
	table.insert(slideRegs,{key=key,def=def,set=setVal, min=min, max=max})
	bar.InputBegan:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then hold=true set(io.Position.X) end
	end)
	UIS.InputEnded:Connect(function(io)
		if io.UserInputType==Enum.UserInputType.MouseButton1 or io.UserInputType==Enum.UserInputType.Touch then hold=false end
	end)
	UIS.InputChanged:Connect(function(io)
		if hold and (io.UserInputType==Enum.UserInputType.MouseMovement or io.UserInputType==Enum.UserInputType.Touch) then set(io.Position.X) end
	end)
	return f
end

-- ================= TABS =================
local side=mk('Frame',{Position=UDim2.new(0,10,0,46),Size=UDim2.new(0,128,1,-56),BackgroundColor3=Color3.fromRGB(20,24,32),BorderSizePixel=0},main)
cr(side,10)
local body=mk('Frame',{Position=UDim2.new(0,146,0,46),Size=UDim2.new(1,-156,1,-56),BackgroundTransparency=1},main)
local pages={}
local tabBtns={}
local tabDefs={'Gerak','Lihat','Tempur','Lain'}
for i,nm in ipairs(tabDefs) do
	local b=mk('TextButton',{Size=UDim2.new(1,-12,0,36),Position=UDim2.new(0,6,0,(i-1)*42+8),Text=nm,Font=Enum.Font.Gotham,TextSize=13,TextColor3=Color3.fromRGB(200,195,190),BackgroundColor3=Color3.fromRGB(26,31,41),BorderSizePixel=0,AutoButtonColor=true},side)
	cr(b,8)
	tabBtns[nm]=b
	local f=mk('ScrollingFrame',{Name=nm,Size=UDim2.new(1,0,1,0),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(80,140,230),AutomaticCanvasSize=Enum.AutomaticSize.Y,Visible=false},body)
	mk('UIListLayout',{Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},f)
	mk('UIPadding',{PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,2)},f)
	pages[nm]=f
	b.MouseButton1Click:Connect(function()
		for n,fr in pairs(pages) do fr.Visible=(n==nm) end
		for n,bt in pairs(tabBtns) do
			bt.BackgroundColor3=(n==nm) and Color3.fromRGB(45,90,160) or Color3.fromRGB(26,31,41)
		end
	end)
end
pages['Gerak'].Visible=true
tabBtns['Gerak'].BackgroundColor3=Color3.fromRGB(45,90,160)

-- ================= ISI =================
sect(pages['Gerak'],'KECEPATAN (tulis hanya saat digeser)')
slide(pages['Gerak'],'WalkSpeed',16,300,30,function(v) SavedWS=v SpeedDirty=true local c=lp.Character local h=c and c:FindFirstChildOfClass('Humanoid') if h then h.WalkSpeed=v end end,'ws')
slide(pages['Gerak'],'JumpPower',50,300,50,function(v) SavedJP=v JumpDirty=true local c=lp.Character local h=c and c:FindFirstChildOfClass('Humanoid') if h then if not h.UseJumpPower then h.UseJumpPower=true end h.JumpPower=v end end,'jp')
sect(pages['Gerak'],'TERBANG')
slide(pages['Gerak'],'Fly Speed',20,200,70,function(v) S.flySpd=v end,'flySpd')
tog(pages['Gerak'],'Fly (WASD + Spasi)','fly',function(on) setFly(on) end)
tog(pages['Gerak'],'Noclip','nc')
tog(pages['Gerak'],'Infinite Jump','ij')
sect(pages['Gerak'],'TELEPORT')
btn(pages['Gerak'],'📍 Simpan Posisi',function()
	local hrp=lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
	if hrp then SavedPos=hrp.CFrame log('Posisi disimpan.') end
end)
btn(pages['Gerak'],'🚀 Ke Posisi Tersimpan',function()
	local hrp=lp.Character and lp.Character:FindFirstChild('HumanoidRootPart')
	if hrp and SavedPos then hrp.CFrame=SavedPos log('Teleport OK.') else log('Belum ada posisi.') end
end)

sect(pages['Lihat'],'ESP')
tog(pages['Lihat'],'ESP Pemain','espP')
tog(pages['Lihat'],'ESP Airdrop / Hadiah','espC')
sect(pages['Lihat'],'MAGNET ORB DARAH (+25)')
tog(pages['Lihat'],'Magnet Orb (tarik orb ke kamu)','magnetOrb',function(on)
	if on then log('Magnet Orb ON.') else log('Magnet Orb OFF.') end
end)
slide(pages['Lihat'],'Jangkauan magnet (stud)',10,300,60,function(v) S.magnetRange=v end,'magnetRange')
sect(pages['Lihat'],'LAYAR')
tog(pages['Lihat'],'Fullbright','fb',function(on)
	if not on then
		pcall(function()
			Lighting.Brightness=oFB[1]
			Lighting.Ambient=oFB[2]
			Lighting.OutdoorAmbient=oFB[3]
			Lighting.ClockTime=oFB[4]
			Lighting.GlobalShadows=oFB[5]
		end)
	end
end)
btn(pages['Lihat'],'⚡ FPS Boost',function()
	for _,v in pairs(Workspace:GetDescendants()) do
		if v:IsA('BasePart') then v.Material=Enum.Material.SmoothPlastic v.Reflectance=0
		elseif v:IsA('Decal') or v:IsA('Texture') then v.Transparency=1
		elseif v:IsA('ParticleEmitter') or v:IsA('Trail') then v.Enabled=false end
	end
	Lighting.GlobalShadows=false
	log('FPS Boost OK (rejoin untuk pulihkan).')
end)

sect(pages['Tempur'],'AIMBOT (musuh tim lain)')
tog(pages['Tempur'],'Aimbot','aim')
tog(pages['Tempur'],'Hanya saat ADS (klik kanan)','aimADS')
tog(pages['Tempur'],'Hanya yang terlihat','aimVis')
tog(pages['Tempur'],'Auto Headshot (bidik kepala)','aimHead')
tog(pages['Tempur'],'Ikut target NPC / Monster','aimNPC')
tog(pages['Tempur'],'Tampilkan lingkaran FOV','fovShow')
slide(pages['Tempur'],'FOV Aim (px)',50,400,140,function(v) S.aimFov=v end)
slide(pages['Tempur'],'Kehalusan (1 licin - 20 kaku)',1,20,8,function(v) S.aimSmooth=v end)
sect(pages['Tempur'],'BIG HEAD (hitbox kepala musuh)')
tog(pages['Tempur'],'Big Head (kepala musuh besar)','bigHead',function(on)
	if on then
		applyBigHead()
		log('Big Head ON.')
	else
		restoreHeads()
		log('Big Head OFF.')
	end
end)
slide(pages['Tempur'],'Ukuran Kepala (1 - 8)',1,8,3,function(v) S.headSize=v if S.bigHead then applyBigHead() end end)
sect(pages['Tempur'],'NO SPREAD (peluru lurus)')
tog(pages['Tempur'],'No Spread (peluru lurus, tanpa sebar)','noSpread',function(on)
	if on then
		local ok=hookNoSpread()
		if ok then log('No Spread ON.') else log('No Spread gagal (hook).') end
	else
		unhookNoSpread()
		log('No Spread OFF.')
	end
end)
sect(pages['Tempur'],'TRIGGERBOT')
tog(pages['Tempur'],'Tembak otomatis saat crosshair pas','trig')
slide(pages['Tempur'],'Jeda tembak (ms)',50,400,120,function(v) S.trigDelay=v end)
sect(pages['Tempur'],'ESP MUSUH')
tog(pages['Tempur'],'ESP Musuh (kotak + Nama/HP/jarak)','espM')
tog(pages['Tempur'],'Skeleton ESP (hijau=terlihat, merah=tertutup)','espB')

sect(pages['Lain'],'UTILITAS')
tog(pages['Lain'],'Anti AFK','afk')
btn(pages['Lain'],'🖱 Cursor Bebas / Kunci',function()
	setCursorFree(not CursorFree)
	log(CursorFree and 'Cursor bebas.' or 'Cursor dikunci.')
end)
btn(pages['Lain'],'🧹 Reset Total',function() resetAll() end)
btn(pages['Lain'],'🔄 Respawn',function()
	local h=lp.Character and lp.Character:FindFirstChildOfClass('Humanoid')
	if h then h.Health=0 end
end)
btn(pages['Lain'],'🔁 Rejoin',function()
	TeleportService:TeleportToPlaceInstance(game.PlaceId,game.JobId,lp)
end)

-- ================= LOGIKA =================
local flyConn=nil
function setFly(on)
	if on then
		local c=lp.Character
		local hum=c and c:FindFirstChildOfClass('Humanoid')
		if hum then hum.PlatformStand=true end
		if flyConn then flyConn:Disconnect() end
		flyConn=RunService.Heartbeat:Connect(function(dt)
			if ENV.AAD_GEN~=MYGEN then return end
			dt=math.min(dt or 0.016,0.05)
			local cc=lp.Character
			local hh=cc and cc:FindFirstChild('HumanoidRootPart')
			local hu=cc and cc:FindFirstChildOfClass('Humanoid')
			if not S.fly or not hh then return end
			local cam=Workspace.CurrentCamera
			if not cam then return end
			local d=Vector3.zero
			if UIS:IsKeyDown(Enum.KeyCode.W) then d+=cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then d-=cam.CFrame.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then d-=cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then d+=cam.CFrame.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then d+=Vector3.new(0,1,0) end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then d-=Vector3.new(0,1,0) end
			if d.Magnitude>0.01 then
				hh.CFrame=hh.CFrame+(d.Unit*S.flySpd*dt)
			end
			pcall(function() hh.AssemblyLinearVelocity=Vector3.zero end)
			if hu then hu.PlatformStand=true end
		end)
	else
		if flyConn then flyConn:Disconnect() flyConn=nil end
		local c=lp.Character
		local hum=c and c:FindFirstChildOfClass('Humanoid')
		if hum then hum.PlatformStand=false end
	end
end

function resetAll()
	S.espP=false S.espC=false S.fb=false
	S.magnetOrb=false
	S.fly=false S.nc=false S.ij=false S.afk=false
	S.aim=false S.trig=false S.espM=false S.espB=false S.fovShow=false
	S.bigHead=false S.headSize=3
	pcall(function() restoreHeads() end)
	S.noSpread=false
	pcall(function() unhookNoSpread() end)
	setFly(false)
	setCursorFree(false)
	pcall(cleanupCombat)
	pcall(function()
		Lighting.Brightness=oFB[1]
		Lighting.Ambient=oFB[2]
		Lighting.OutdoorAmbient=oFB[3]
		Lighting.ClockTime=oFB[4]
		Lighting.GlobalShadows=oFB[5]
	end)
	pcall(function()
		local c=lp.Character
		if c then
			for _,p in ipairs(c:GetDescendants()) do
				if p:IsA('BasePart') then p.CanCollide=(p.Name~='HumanoidRootPart') end
			end
			local h=c:FindFirstChildOfClass('Humanoid')
			if h then h.WalkSpeed=30 h.JumpPower=50 end
		end
	end)
	for _,h in pairs(espReg) do pcall(function() h:Destroy() end) end
	espReg={}
	pcall(function()
		for _,v in pairs(Workspace:GetDescendants()) do
			if (v:IsA('Highlight') and (v.Name=='AAD_P' or v.Name=='AAD_C' or v.Name=='AAD_E'))
				or (v:IsA('BillboardGui') and (v.Name=='AAD_CBB' or v.Name=='AAD_EBB')) then
				pcall(function() v:Destroy() end)
			end
		end
	end)
	ENV.AAD_GEN=(ENV.AAD_GEN or 0)+1
	MYGEN=ENV.AAD_GEN
for _,s in ipairs(slideRegs) do pcall(function() s.set(s.def) end) end
S.headSize=3
SavedWS,SavedJP=30,50
	SpeedDirty,JumpDirty=false,false
	for _,ps in pairs(togPainters) do for _,p in ipairs(ps) do pcall(p) end end
	log('Reset total: normal lagi (FPS Boost butuh rejoin).')
end

-- noclip halus
task.spawn(function()
	while alive() do
		if S.nc then
			local c=lp.Character
			if c then
				for _,p in ipairs(c:GetDescendants()) do
					if p:IsA('BasePart') and p.CanCollide then p.CanCollide=false end
				end
			end
		end
		task.wait(0.3)
	end
end)
UIS.JumpRequest:Connect(function()
	if ENV.AAD_GEN~=MYGEN then return end
	if S.ij and lp.Character then
		local h=lp.Character:FindFirstChildOfClass('Humanoid')
		if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)
lp.Idled:Connect(function()
	if S.afk then
		pcall(function()
			game:GetService('VirtualUser'):CaptureController()
			game:GetService('VirtualUser'):ClickButton2(Vector2.new())
		end)
	end
end)

-- ESP pemain (humanoid, bukan diri sendiri) + NPC/pickup
local function clearTag(tag)
	for _,v in pairs(Workspace:GetDescendants()) do
		if v:IsA('Highlight') and v.Name==tag then pcall(function() v:Destroy() end) end
	end
end
local function anchorOf(m)
	return m:FindFirstChild('Head') or m:FindFirstChild('HumanoidRootPart') or m:FindFirstChildWhichIsA('BasePart',true)
end
local function isPlayerChar(m)
	if m==lp.Character then return false end
	if not m:FindFirstChildOfClass('Humanoid') then return false end
	if not m:FindFirstChild('HumanoidRootPart') then return false end
	if not Players:GetPlayerFromCharacter(m) then return false end
	return true
end
local function isDrop(m)
	if not m:IsA('Model') then return false end
	local n=m.Name:lower()
	return n:find('chest',1,true) or n:find('crate',1,true) or n:find('supply',1,true)
		or n:find('drop',1,true) or n:find('airdrop',1,true) or n:find('air',1,true)
		or n:find('loot',1,true) or n:find('peti',1,true) or n:find('box',1,true)
		or n:find('ammo',1,true) or n:find('health',1,true) or n:find('pickup',1,true)
		or n:find('gift',1,true) or n:find('wint',1,true) or n:find('hadiah',1,true)
		or n:find('npc',1,true) or n:find('monster',1,true)
end
local function isDropFolder(m)
	local di=Workspace:FindFirstChild('DropItemFloder')
	return di and m:IsDescendantOf(di) or false
end
task.spawn(function()
	while alive() do
		if S.espP then
			for _,m in ipairs(Workspace:GetChildren()) do
				if m:IsA('Model') and isPlayerChar(m) and not m:FindFirstChild('AAD_P') then
					local h=Instance.new('Highlight')
					h.Name='AAD_P' h.FillColor=Color3.fromRGB(255,70,70)
					h.FillTransparency=0.6 h.Adornee=m h.Parent=m
				end
			end
		else
			clearTag('AAD_P')
		end
		if S.espC then
			for _,m in ipairs(Workspace:GetDescendants()) do
				if (isDrop(m) or isDropFolder(m)) and not m:FindFirstChild('AAD_C') then
					local h=Instance.new('Highlight')
					h.Name='AAD_C' h.FillColor=Color3.fromRGB(255,200,60)
					h.FillTransparency=0.5 h.Adornee=m h.Parent=m
					local an=anchorOf(m)
					if an then
						local bb=Instance.new('BillboardGui')
						bb.Name='AAD_CBB' bb.Size=UDim2.new(0,130,0,26)
						bb.StudsOffset=Vector3.new(0,3,0) bb.AlwaysOnTop=true bb.Parent=an
						local tx=Instance.new('TextLabel')
						tx.Size=UDim2.new(1,0,1,0) tx.BackgroundColor3=Color3.fromRGB(10,10,15)
						tx.BackgroundTransparency=0.3 tx.Font=Enum.Font.GothamBold tx.TextSize=12
						tx.TextColor3=Color3.fromRGB(255,210,100) tx.TextStrokeTransparency=0.2
						tx.Text=m.Name tx.Parent=bb
						mk('UICorner',{CornerRadius=UDim.new(0,6)},tx)
					end
				end
			end
		else
			clearTag('AAD_C')
			for _,v in pairs(Workspace:GetDescendants()) do
				if v:IsA('BillboardGui') and v.Name=='AAD_CBB' then pcall(function() v:Destroy() end) end
			end
		end
		task.wait(2)
	end
end)

-- fullbright saat ON (snapshot dipulihkan saat OFF/reset)
task.spawn(function()
	while alive() do
		if S.fb then
			Lighting.Brightness=2 Lighting.ClockTime=14
			Lighting.FogEnd=100000 Lighting.GlobalShadows=false
		end
		task.wait(1)
	end
end)

-- ================= MAGNET ORB DARAH (+25) =================
-- Game ini: orb darah muncul dari jasad, server yang menariknya smooth fly ke
-- pemain terdekat lalu memberi +25 HP. Tidak ada remote client untuk klaim orb
-- → strategi: geser RootPart model "BoostHealth" ke karakter kita. Karakter
-- TIDAK digerakkan sama sekali → ritme aim/tembak aman.
-- Diagnosa: getgenv().AAD_MAG = {orbs, try, moved, claimed, owner, last}.
ENV.AAD_MAG=ENV.AAD_MAG or {orbs=0,try=0,moved=0,claimed=0,owner='?',last='',hp=0}
local MAG=ENV.AAD_MAG
local function orbModelOf(v)
	if not v:IsA('Model') or v.Name~='BoostHealth' then return nil end
	local cf=Workspace:FindFirstChild('Cache')
	if cf and v:IsDescendantOf(cf) then return nil end -- template, bukan orb hidup
	return v
end
local lastHP=nil
task.spawn(function()
	while alive() do
		pcall(function()
			local c=lp.Character
			local hrp=c and c:FindFirstChild('HumanoidRootPart')
			local hum=c and c:FindFirstChildOfClass('Humanoid')
			if not (hrp and hum and hum.Health>0) then lastHP=nil return end
			local hp=hum.Health
			-- hitung klaim: HP naik saat magnet ON
			if S.magnetOrb and lastHP and hp>lastHP+0.5 then
				MAG.claimed=MAG.claimed+1
			end
			lastHP=hp
			MAG.hp=math.floor(hp)
			if not S.magnetOrb then return end
			local me=hrp.Position
			local range=S.magnetRange or 60
			local nOrb,best,bestD=0,nil,nil
			for _,v in ipairs(Workspace:GetDescendants()) do
				local mdl=orbModelOf(v)
				if mdl then
					local root=mdl:FindFirstChild('RootPart') or mdl.PrimaryPart
						or mdl:FindFirstChildWhichIsA('BasePart',true)
					if root then
						nOrb=nOrb+1
						local d=(root.Position-me).Magnitude
						if d<=range and (not bestD or d<bestD) then
							bestD=d best=root
						end
					end
				end
			end
			MAG.orbs=nOrb
			if best then
				MAG.try=MAG.try+1
				MAG.last=string.format('%.0fm',bestD)
				pcall(function()
					if not best.Anchored then best.CanCollide=false best.Massless=true end
					local ok,o=pcall(function() return best:GetNetworkOwner() end)
					if ok then MAG.owner=(type(o)=='userdata' and 'server') or tostring(o) end
				end)
				-- ler pingkahal: fly halus ke posisi karakter (dua tick ~0.3s)
				local goal=me+Vector3.new(0,1.5,0)
				pcall(function()
					best.CFrame=best.CFrame:Lerp(CFrame.new(goal),0.45)
				end)
				MAG.moved=MAG.moved+1
			end
		end)
		task.wait(0.15)
	end
end)

-- ================= TEMPUR =================
-- TOAST lock di luar HUD
local toastCache=nil
local toast=mk('TextLabel',{Size=UDim2.new(0,270,0,38),Position=UDim2.new(0.5,-135,0,64),BackgroundColor3=Color3.fromRGB(12,13,20),BackgroundTransparency=0.15,Text='',Font=Enum.Font.GothamBold,TextSize=15,TextColor3=Color3.fromRGB(120,255,160),TextTruncate=Enum.TextTruncate.AtEnd,BorderSizePixel=0,Visible=false},gui)
cr(toast,10)
mk('UIStroke',{Color=Color3.fromRGB(70,110,180),Thickness=1.2},toast)
local function showToast(t,col)
	if t~=toastCache then
		toastCache=t
		toast.Text=t
		toast.TextColor3=col or Color3.fromRGB(120,255,160)
		toast.Visible=true
	end
end
local function hideToast()
	if toastCache~=nil then
		toastCache=nil
		toast.Visible=false
	end
end

-- Tim: game ini FFA (lp.Team = nil saat probe) -> semua pemain lain = musuh.
-- Kalau game nanti menambah tim, cek tim tetap dipakai (aman untuk kedua mode).
local function myTeam() return lp.Team end
local function aliveHum(m)
	local h=m and m:FindFirstChildOfClass('Humanoid')
	if h and h.Health>0 then return h end
	return nil
end
local function playerOfChar(m)
	for _,p in ipairs(Players:GetPlayers()) do
		if p.Character==m then return p end
	end
	return nil
end
-- musuh: pemain lain dengan tim BERBEDA (atau tanpa tim info)
local function enemyOK(m,plr)
	if m==lp.Character then return false end
	if not aliveHum(m) then return false end
	if not m:FindFirstChild('HumanoidRootPart') then return false end
	if not plr then return S.aimNPC end
	if plr==lp then return false end
	local mt,ot=myTeam(),plr.Team
	if mt and ot and mt==ot then return false end
	return true
end

local rparams=RaycastParams.new()
rparams.FilterType=Enum.RaycastFilterType.Exclude
rparams.IgnoreWater=true
local function visibleRaw(camPos,part,charM)
	-- Raycast tembus-pandang: part yang tak terlihat mata (Transparency>0.5,
	-- mis. backdrop/trigger raksasa invisible ber-CanQuery) tidak dianggap
	-- penghalang. Hanya dinding opaque yang menutup target.
	rparams.FilterDescendantsInstances={lp.Character}
	local toT=part.Position-camPos
	local unit=toT.Unit
	local origin=camPos
	local remain=toT.Magnitude
	for _=1,6 do
		local res=Workspace:Raycast(origin,unit*remain,rparams)
		if not res then return true end
		local hit=res.Instance
		if hit:IsDescendantOf(charM) then return true end
		if hit.Transparency>0.5 then
			local adv=(res.Position-origin).Magnitude+0.5
			origin=origin+unit*adv
			remain=remain-adv
			if remain<=0.5 then return true end
		else
			return false
		end
	end
	return false
end

-- ================= BIG HEAD (hitbox kepala musuh) =================
-- Cara kerja: hit detection senjata game ini jalan di client (raycast dari
-- kameramu), jadi kepala yang dibesarkan di client ikut kena raycast ->
-- headshot jauh lebih mudah. Tidak replikasi ke server (FilteringEnabled),
-- jadi aman: hanya tampilan + hitbox di layarmu.
applyBigHead=function()
	for hd in pairs(headOrig) do
		if not hd.Parent then headOrig[hd]=nil end
	end
	for _,pl in ipairs(Players:GetPlayers()) do
		if pl~=lp then
			local m=pl.Character
			local hd=m and m:FindFirstChild('Head')
			if hd and hd:IsA('BasePart') then
				if not headOrig[hd] then
					headOrig[hd]={Size=hd.Size,Transparency=hd.Transparency,CanCollide=hd.CanCollide}
				end
				local base=headOrig[hd].Size
				local k=S.headSize or 3
				hd.Size=Vector3.new(base.X*k,base.Y*k,base.Z*k)
				hd.Transparency=0.6
				hd.CanCollide=false
			end
		end
	end
end
restoreHeads=function()
	for hd,orig in pairs(headOrig) do
		pcall(function()
			hd.Size=orig.Size
			hd.Transparency=orig.Transparency
			hd.CanCollide=orig.CanCollide
		end)
		headOrig[hd]=nil
	end
end
-- sapu respawn: kepala baru muncul normal, terapkan ulang tiap detik saat ON
task.spawn(function()
	while alive() do
		if S.bigHead then pcall(applyBigHead) end
		task.wait(1)
	end
end)

-- ================= NO SPREAD (peluru lurus) =================
-- Fakta terverifikasi dari kode game (ReplicatedStorage.Scripts.Model.Blaster):
-- arah peluru (rayDirections) + hasil raycast (rayResults) dihitung DI CLIENT
-- oleh Blaster:GetRayResults() memakai Blaster:GetSpread() — di situlah sebar
-- peluru berasal (hip-fire besar, scope kecil). Jadi fix paling bersih:
--   patch Blaster.GetSpread() agar selalu return 0 → hip-fire & scope lurus.
-- Butuh executor dengan require() (Xeno laptop: require diblokir → fallback
-- hook FireServer di bawah; di executor HP ini require jalan).
local NS=ENV.AAD_NS
if type(NS)~='table' then
	NS={on=false,hooked=false,patched=false,shots=0,dirs=0,logs={},inst=nil}
	ENV.AAD_NS=NS
else
	-- File dijalankan ulang (eksekusi manual / queue pasca-teleport). Module
	-- cache BISA baru (teleport) → wrapper lama tidak terpasang lagi, jadi
	-- flag direset dan dipasang ulang oleh blok di bawah.
	-- origSpread/lastWrapped TIDAK direset (identitas wrapper dipakai patchBlaster
	-- untuk membedakan cache baru vs wrapper lama yang masih terpasang).
	NS.patched=false NS.hooked=false NS.blaster=nil NS.inst=nil
end
-- TouchEnabled belum tentu berarti HP (Xeno PC dengan Precision?). Probabilitas
-- ini hanya dipakai mengatur urutan: API game dulu, klik OS paling akhir.
local TouchMode=false
pcall(function() TouchMode=UIS.TouchEnabled==true end)
local MainRemote=RS:FindFirstChild('RemoteEvent') and RS.RemoteEvent:FindFirstChild('Main')
local function straighten(payload)
	-- Fallback: rayDirections = vektor offset dunia (arah*range), bukan posisi.
	-- Rapatkan: offset jadi look*range → semua ray lurus ke tengah kamera.
	if type(payload)~='table' then return end
	local params=payload[2]
	if type(params)~='table' then return end
	local dirs=params.rayDirections
	if type(dirs)~='table' or #dirs<1 then return end
	local cam=Workspace.CurrentCamera
	if not cam then return end
	local look=cam.CFrame.LookVector
	for i=1,#dirs do
		local d=dirs[i]
		if typeof(d)=='Vector3' then
			dirs[i]=look*d.Magnitude
		end
	end
end
local function patchBlaster()
	-- require modul Blaster → wrap GetSpread: (a) capture instance senjata aktif
	-- (self) untuk triggerbot & magnet, (b) return 0 saat NS.on untuk no-spread.
	local ok,err=pcall(function()
		local Blaster=require(RS.Scripts.Model.Blaster)
		if type(Blaster)~='table' or type(Blaster.GetSpread)~='function' then error('GetSpread tak ada') end
		-- Hanya simpan "asli" kalau current BUKAN wrapper lama kita (identitas dari
		-- NS.lastWrapped). Kalau cache sama + wrapper lama masih terpasang, origSpread
		-- yang lama (fungsi asli) tetap benar — jangan timpa dengan wrapper.
		local cur=Blaster.GetSpread
		if not NS.origSpread or NS.lastWrapped~=cur then
			NS.origSpread=cur
		end
		local orig=NS.origSpread
		local wrapped=function(self,...)
			if type(self)=='table' and not NS.inst then
				-- Blaster instance asli: punya propMap/GetRaysPerShot (dicek aman)
				local isInst=false
				pcall(function() isInst=(self.GetRaysPerShot~=nil or self.propMap~=nil) end)
				if isInst then NS.inst=self end
			end
			if NS.on then return 0 end
			return orig(self,...)
		end
		Blaster.GetSpread=wrapped
		NS.lastWrapped=wrapped
		NS.blaster=Blaster
		NS.patched=true
		NS.logs[#NS.logs+1]='patch GetSpread OK'
	end)
	if not ok and #NS.logs<8 then NS.logs[#NS.logs+1]='patch gagal: '..tostring(err) end
	return ok
end
hookNoSpread=function()
	NS.on=true
	-- Wrapper dipasang permanen sejak load (capture instance untuk triggerbot);
	-- kalau karena suatu hal belum terpasang, pasang sekarang.
	if NS.patched then return true end
	if patchBlaster() then NS.hooked=true return true end
	-- Fallback (executor tanpa require): hook FireServer.
	if NS.hooked then return true end
	if not MainRemote then return false end
	local orig=MainRemote.FireServer
	NS.orig=NS.orig or orig
	local realOrig=NS.orig
	local ok=pcall(function()
		hookfunction(orig,newcclosure(function(self,...)
			if NS.on then
				local a=...
				if type(a)=='table' then
					pcall(function()
						if type(a[2])=='table' and type(a[2].rayDirections)=='table' then
							NS.shots=NS.shots+1
							local rd=a[2].rayDirections
							if #NS.logs<8 then
								local okM,mag=pcall(function() return rd[1].Magnitude end)
								NS.logs[#NS.logs+1]='#'..NS.shots..' proto='..tostring(a[1])
									..' nDir='..#rd..' mag='..tostring(okM and mag)
								NS.dirs=NS.dirs+#rd
							end
							straighten(a)
						end
					end)
				end
			end
			return realOrig(self,...)
		end))
	end)
	NS.hooked=ok
	return ok
end
unhookNoSpread=function()
	NS.on=false
	-- GetSpread wrapper sengaja TIDAK dilepas: triggerbot butuh NS.inst (capture
	-- dilakukan di wrapper itu). Menonaktifkan no-spread cukup NS.on=false, jadi
	-- fungsi asli dipanggil dan spread normal kembali.
end
-- Wrapper dipasang SEKALI saat load (bukan hanya saat toggle ON) supaya
-- NS.inst capture terus berjalan even ketika no-spread OFF.
do
	local ok=pcall(patchBlaster)
	if not ok then
		-- executor tanpa require → pakai jalur hook FireServer classic
		NS.on=false
	end
end
-- pulihkan keadaan sesuai state script sekarang
NS.on=S.noSpread and true or false

-- REGISTER BONUS DRAWCALL =================
local fovCircle=nil
local boneOK=false
local R15SEG={
	{'Head','UpperTorso'},{'UpperTorso','LowerTorso'},
	{'UpperTorso','LeftUpperArm'},{'LeftUpperArm','LeftLowerArm'},{'LeftLowerArm','LeftHand'},
	{'UpperTorso','RightUpperArm'},{'RightUpperArm','RightLowerArm'},{'RightLowerArm','RightHand'},
	{'LowerTorso','LeftUpperLeg'},{'LeftUpperLeg','LeftLowerLeg'},{'LeftLowerLeg','LeftFoot'},
	{'LowerTorso','RightUpperLeg'},{'RightUpperLeg','RightLowerLeg'},{'RightLowerLeg','RightFoot'},
}
local R6SEG={
	{'Head','Torso'},{'Torso','Left Arm'},{'Torso','Right Arm'},
	{'Torso','Left Leg'},{'Torso','Right Leg'},
}
local boneReg={}
local espMReg={}
local function clearBones()
	for m,ls in pairs(boneReg) do
		for _,l in ipairs(ls) do pcall(function() l:Remove() end) end
		boneReg[m]=nil
	end
end
local function hideAllBones()
	for _,ls in pairs(boneReg) do
		for _,l in ipairs(ls) do pcall(function() l.Visible=false end) end
	end
end
local function trackDraw(l)
	pcall(function()
		ENV.AAD_BONES=ENV.AAD_BONES or {}
		table.insert(ENV.AAD_BONES,l)
	end)
end
cleanupCombat=function()
	if fovCircle then pcall(function() fovCircle.Visible=false end) end
	hideAllBones()
	clearBones()
	for m,v in pairs(espMReg) do
		for _,o in pairs(v) do pcall(function() o:Destroy() end) end
		espMReg[m]=nil
	end
	hideToast()
end
pcall(function()
	if Drawing then
		boneOK=true
		local t=Drawing.new('Line')
		t.Visible=false
		t:Remove()
		fovCircle=Drawing.new('Circle')
		fovCircle.Visible=false
		fovCircle.Thickness=1.5
		fovCircle.Color=Color3.fromRGB(110,160,255)
		fovCircle.Filled=false
		ENV.AAD_FOV=fovCircle
	end
end)

-- ================= REGISTRASI ESP MUSUH (kotak + label) =================
local function buildEnemyESP(m)
	local v={}
	local hl=Instance.new('Highlight')
	hl.Name='AAD_E'
	hl.FillColor=Color3.fromRGB(255,60,60)
	hl.FillTransparency=0.65
	hl.OutlineColor=Color3.fromRGB(255,255,255)
	hl.OutlineTransparency=0.4
	hl.Adornee=m
	hl.Parent=m
	v[1]=hl
	local an=m:FindFirstChild('Head') or m:FindFirstChild('HumanoidRootPart')
	if an then
		local bb=Instance.new('BillboardGui')
		bb.Name='AAD_EBB'
		bb.Size=UDim2.new(0,170,0,34)
		bb.StudsOffset=Vector3.new(0,3.2,0)
		bb.AlwaysOnTop=true
		bb.Parent=an
		mk('UICorner',{CornerRadius=UDim.new(0,6)},bb)
		local tx=Instance.new('TextLabel')
		tx.Name='Label'
		tx.Size=UDim2.new(1,0,1,0)
		tx.BackgroundColor3=Color3.fromRGB(10,10,15)
		tx.BackgroundTransparency=0.25
		tx.Font=Enum.Font.GothamBold
		tx.TextSize=12
		tx.TextColor3=Color3.fromRGB(255,180,180)
		tx.TextStrokeTransparency=0.2
		tx.Text='…'
		tx.Parent=bb
		mk('UICorner',{CornerRadius=UDim.new(0,6)},tx)
		v[2]=bb
		v[3]=tx
	end
	espMReg[m]=v
end
local function dropEnemyESP(m)
	local v=espMReg[m]
	if not v then return end
	for _,o in pairs(v) do pcall(function() o:Destroy() end) end
	espMReg[m]=nil
end
-- ================= END REGISTRASI =================

local function aimPoint(m)
	if S.aimHead then
		local hd=m:FindFirstChild('Head')
		if hd and hd:IsA('BasePart') then return hd end
	end
	return m:FindFirstChild('UpperTorso') or m:FindFirstChild('Torso')
		or m:FindFirstChild('HumanoidRootPart') or m:FindFirstChild('Head')
end
local AimLast={name=nil,fov=0,blk=0}
local function bestTarget()
	local cam=Workspace.CurrentCamera
	if not cam then return nil,nil end
	local cpos=cam.CFrame.Position
	local best,bestScore,bestVis=nil,math.huge,nil
	local nFov,nBlk=0,0
	local function consider(m,plr)
		if not enemyOK(m,plr) then return end
		local anchor=m:FindFirstChild('HumanoidRootPart') or m:FindFirstChild('Head')
		if anchor and (anchor.Position-cpos).Magnitude<4 then return end
		-- urutan kandidat titik bidik
		local cands={}
		if S.aimHead then
			local hd=m:FindFirstChild('Head')
			if hd and hd:IsA('BasePart') then cands[#cands+1]=hd end
		end
		for _,p in ipairs({m:FindFirstChild('UpperTorso'),m:FindFirstChild('Torso'),m:FindFirstChild('HumanoidRootPart')}) do
			if p and p:IsA('BasePart') then cands[#cands+1]=p end
		end
		if #cands==0 then return end
		local inFov,chosen=false,nil
		for _,ap in ipairs(cands) do
			local sp,on=cam:WorldToViewportPoint(ap.Position)
			if on then
				local vs=cam.ViewportSize
				local dx,dy=sp.X-vs.X/2,sp.Y-vs.Y/2
				local px=math.sqrt(dx*dx+dy*dy)
				if px<=S.aimFov then
					inFov=true
					if not S.aimVis or visibleRaw(cpos,ap,m) then chosen=ap break end
				end
			end
		end
		if not inFov then nFov=nFov+1 return end
		if not chosen then nBlk=nBlk+1 return end
		local sp=cam:WorldToViewportPoint(chosen.Position)
		local vs=cam.ViewportSize
		local dx,dy=sp.X-vs.X/2,sp.Y-vs.Y/2
		local px=math.sqrt(dx*dx+dy*dy)
		local score=px+(chosen.Position-cpos).Magnitude*0.05
		if score<bestScore then bestScore=score best=m bestVis=chosen end
	end
	for _,pl in ipairs(Players:GetPlayers()) do consider(pl.Character,pl) end
	if S.aimNPC then
		for _,m in ipairs(Workspace:GetChildren()) do
			if m:IsA('Model') and m~=lp.Character and not playerOfChar(m) and m:FindFirstChildOfClass('Humanoid') then
				consider(m,nil)
			end
		end
	end
	AimLast={name=best and best.Name or nil,fov=nFov,blk=nBlk}
	return best,bestVis
end

-- ================= LOOP UTAMA TEMPUR =================
RunService.RenderStepped:Connect(function()
	if ENV.AAD_GEN~=MYGEN then
		cleanupCombat()
		return
	end
	local cam=Workspace.CurrentCamera
	-- lingkaran FOV
	if fovCircle then
		local show=S.aim and S.fovShow
		fovCircle.Visible=show
		if show and cam then
			fovCircle.Position=cam.ViewportSize/2
			fovCircle.Radius=S.aimFov
		end
	end
	-- SKELETON ESP
	if S.espB and boneOK then
		if not cam then return end
		local cpos=cam.CFrame.Position
		for m in pairs(espMReg) do
			if not m.Parent then
				dropEnemyESP(m)
			end
		end
		for m,ls in pairs(boneReg) do
			if not espMReg[m] then
				for _,l in ipairs(ls) do pcall(function() l:Remove() end) end
				boneReg[m]=nil
			end
		end
		for m in pairs(espMReg) do
			local segs=m:FindFirstChild('UpperTorso') and R15SEG or R6SEG
			local ls=boneReg[m]
			if not ls then ls={} boneReg[m]=ls end
			while #ls<#segs do
				local l=Drawing.new('Line')
				l.Visible=false
				l.Thickness=1.5
				table.insert(ls,l)
				trackDraw(l)
			end
			local chest=m:FindFirstChild('UpperTorso') or m:FindFirstChild('Torso') or m:FindFirstChild('HumanoidRootPart')
			local vis=chest and visibleRaw(cpos,chest,m) or true
			local col=vis and Color3.fromRGB(0,255,130) or Color3.fromRGB(255,70,70)
			for i,pr in ipairs(segs) do
				local a=m:FindFirstChild(pr[1])
				local b=m:FindFirstChild(pr[2])
				local l=ls[i]
				if l and a and b and a:IsA('BasePart') and b:IsA('BasePart') then
					local p1,o1=cam:WorldToViewportPoint(a.Position)
					local p2,o2=cam:WorldToViewportPoint(b.Position)
					l.From=Vector2.new(p1.X,p1.Y)
					l.To=Vector2.new(p2.X,p2.Y)
					l.Color=col
					l.Visible=o1 and o2
				elseif l then
					l.Visible=false
				end
			end
		end
	elseif boneOK then
		hideAllBones()
	end
	-- AIMBOT
	if not S.aim then
		hideToast()
		return
	end
	if S.aimADS and not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
	if not cam then return end
	local t,vis=bestTarget()
	if t then
		local ap=vis or aimPoint(t)
		if ap then
			local k=math.clamp(S.aimSmooth/20,0.05,1)
			local goal=CFrame.lookAt(cam.CFrame.Position,ap.Position)
			cam.CFrame=cam.CFrame:Lerp(goal,k)
			local dd=math.floor((ap.Position-cam.CFrame.Position).Magnitude)
			showToast((S.aimHead and ap.Name=='Head' and '🎯 ' or '🔒 ')..tostring(t.Name)..' • '..dd..'m',Color3.fromRGB(120,255,160))
		end
	else
		showToast('🎯 mencari… ('..AimLast.fov..' luar · '..AimLast.blk..' tutup)',Color3.fromRGB(150,160,180))
	end
end)

-- ================= TRIGGERBOT =================
-- mouse1click = klik OS-level: tembus keluar Roblox bila dipicu saat window tidak
-- fokus / HUD terbuka / di lobby (bug fatal: spam klik ke Chrome). Guard wajib.
local trigBusy=false
local winFocused=true
pcall(function()
	UIS.WindowFocused:Connect(function() winFocused=true end)
	UIS.WindowFocusReleased:Connect(function() winFocused=false end)
end)
local function trigGuards()
	if not winFocused then return false end
	if main.Visible or CursorFree then return false end
	local typing=false
	pcall(function() typing=UIS:GetFocusedTextBox()~=nil end)
	if typing then return false end
	local c=lp.Character
	local h=c and c:FindFirstChildOfClass('Humanoid')
	if not h or h.Health<=0 then return false end
	return true
end
task.spawn(function()
	while true do
		if ENV.AAD_GEN~=MYGEN then return end
		if S.trig and not trigBusy and trigGuards() then
			local ok=pcall(function()
				local cam=Workspace.CurrentCamera
				if not cam then return end
				local cpos=cam.CFrame.Position
				rparams.FilterDescendantsInstances={lp.Character}
				local res=Workspace:Raycast(cpos,cam.CFrame.LookVector*500,rparams)
				if res and res.Instance then
					local m=res.Instance:FindFirstAncestorOfClass('Model')
					if m and enemyOK(m,playerOfChar(m)) then
						trigBusy=true
						task.wait(S.trigDelay/1000)
						local fire=false
						if trigGuards() then
							local cam2=Workspace.CurrentCamera
							if cam2 then
								rparams.FilterDescendantsInstances={lp.Character}
								local res2=Workspace:Raycast(cam2.CFrame.Position,cam2.CFrame.LookVector*500,rparams)
								local m2=res2 and res2.Instance and res2.Instance:FindFirstAncestorOfClass('Model')
								fire=(m2==m)
							end
						end
					if fire then
						-- 1) Jalur API game (aman di HP: TIDAK injeksi klik OS,
						--    jadi input sentuh tidak rusak/terkunci). Instansi
						--    ditangkap oleh wrapper GetSpread (patchBlaster).
						local used=false
						if type(NS)=='table' and type(NS.inst)=='table' then
							-- SemiFire menangani ammo + tempo tembak seperti input asli;
							-- CanShoot menolak saat reload/cooldown/lobby.
							local can=false
							pcall(function() can=(NS.inst:CanShoot(false)==true) end)
							if can then
								used=pcall(function() NS.inst:SemiFire() end)
							end
						end
						-- 2) Fallback klik OS HANYA di non-touch (desktop). Di HP
						--    (touch) itulah sumber bug "layar tidak bisa dimainkan".
						if not used and not TouchMode then
							if mouse1click then pcall(mouse1click)
							elseif mouse1press and mouse1release then
								pcall(function() mouse1press() task.wait(0.05) mouse1release() end)
							end
						end
					end
						task.wait(0.15)
						trigBusy=false
					end
				end
			end)
			if not ok then task.wait(0.5) end
		end
		task.wait(0.05)
	end
end)

-- ================= LOOP ESP MUSUH (daftar + label) =================
task.spawn(function()
	while true do
		if ENV.AAD_GEN~=MYGEN then return end
		if S.espM then
			local cam=Workspace.CurrentCamera
			for _,pl in ipairs(Players:GetPlayers()) do
				local m=pl.Character
				if m and enemyOK(m,pl) and not espMReg[m] then
					buildEnemyESP(m)
				end
			end
			if S.aimNPC then
				for _,mm in ipairs(Workspace:GetChildren()) do
					if mm:IsA('Model') and mm~=lp.Character and not playerOfChar(mm)
						and mm:FindFirstChildOfClass('Humanoid') and not espMReg[mm] then
						buildEnemyESP(mm)
					end
				end
			end
			-- segarkan label + buang yang mati/teleport
			for m in pairs(espMReg) do
				if not m.Parent or not aliveHum(m) then
					dropEnemyESP(m)
				else
					local tx=espMReg[m][3]
					local h=m:FindFirstChildOfClass('Humanoid')
					local ap=aimPoint(m)
					if tx and h and ap and cam then
						local d=math.floor((ap.Position-cam.CFrame.Position).Magnitude)
						tx.Text=string.format('%s  %d/%d  %dm',m.Name,math.floor(h.Health),math.floor(h.MaxHealth),d)
					end
				end
			end
		else
			if next(espMReg) then
				for m in pairs(espMReg) do dropEnemyESP(m) end
			end
		end
		task.wait(0.35)
	end
end)

UIS.InputBegan:Connect(function(io,gp)
	if gp then return end
	if ENV.AAD_GEN~=MYGEN then return end
	if io.KeyCode==Enum.KeyCode.Insert or io.KeyCode==Enum.KeyCode.RightShift then
		main.Visible=not main.Visible
		wm.Visible=main.Visible
		setCursorFree(main.Visible)
	end
end)

-- Jalan otomatis lagi setelah pindah lobby <-> match (teleport antar place).
-- Sumber skrip = GitHub raw (versi terbaru), fallback file lokal.
local AAD_GH='https://raw.githubusercontent.com/SanggonBoy/Arena-AirDrop/main/Arena%20AirDrop.lua'
local AAD_LF='D:/New Downloads/RobloxForFun/Arena AirDrop/Arena AirDrop.lua'
pcall(function()
	if queue_on_teleport then
		queue_on_teleport(([==[
local r=getgenv().request
if r then
	local ok,res=pcall(r,{Url='%s',Method='GET'})
	if ok and type(res)=='table' and res.StatusCode==200 and type(res.Body)=='string' and #res.Body>1000 then
		loadstring(res.Body)()
		return
	end
end
pcall(function() loadstring(readfile('%s'))() end)
]==]):format(AAD_GH,AAD_LF))
	end
end)

-- ================= KONFIGURASI (save / load / auto) =================
-- Semua fitur default OFF tiap eksekusi baru. Save menulis state S + WS/JP ke
-- file JSON; toggle Auto ON = config langsung dipakai saat script dijalankan lagi
-- (eksekusi manual / queue_on_teleport pasca-teleport).
local CFGPATH='ArenaAirDrop-config.json'
local function cfgSnapshot()
	local c={SavedWS=SavedWS,SavedJP=SavedJP}
	for k,v in pairs(S) do
		if type(v)=='boolean' or type(v)=='number' then c[k]=v end
	end
	return c
end
local function applyCfg(c)
	if type(c)~='table' then return 0 end
	local n=0
	for k,v in pairs(c) do
		if k~='SavedWS' and k~='SavedJP' and S[k]~=nil and type(S[k])==type(v) then
			S[k]=v n=n+1
		end
	end
	-- slider: jalankan cb-nya supaya label + efek ikut (ws/jp pakai key 'ws'/'jp')
	for _,r in ipairs(slideRegs) do
		if r.key=='ws' and type(c.SavedWS)=='number' then pcall(r.set,c.SavedWS)
		elseif r.key=='jp' and type(c.SavedJP)=='number' then pcall(r.set,c.SavedJP)
		elseif r.key and S[r.key] then pcall(r.set,S[r.key]) end
	end
	-- repaint toggle + jalankan efeknya (kecuali cfgAuto: hindari save-during-load)
	for k,ps in pairs(togPainters) do for _,p in ipairs(ps) do pcall(p) end end
	for k,cb in pairs(togCbs) do
		if k~='cfgAuto' then pcall(cb,S[k]) end
	end
	return n
end
local function doSave()
	local ok,err=pcall(function()
		game:GetService('HttpService'):JSONEncode(cfgSnapshot()) -- validasi dulu
		writefile(CFGPATH,game:GetService('HttpService'):JSONEncode(cfgSnapshot()))
	end)
	if ok then
		log('Config disimpan ('..CFGPATH..').')
		showToast('💾 Config disimpan',Color3.fromRGB(120,255,160))
	else
		log('Gagal simpan: '..tostring(err))
		showToast('💾 Gagal simpan',Color3.fromRGB(255,120,120))
	end
end
local function doLoad(quiet)
	local ok,raw=pcall(function() return readfile(CFGPATH) end)
	if not ok or type(raw)~='string' or raw=='' then
		log('Belum ada config. Tekan Save dulu.')
		if not quiet then showToast('📂 Belum ada config',Color3.fromRGB(255,200,100)) end
		return false
	end
	local ok2,c=pcall(function() return game:GetService('HttpService'):JSONDecode(raw) end)
	if not ok2 or type(c)~='table' then
		log('Config rusak (JSON tidak valid).')
		if not quiet then showToast('📂 Config rusak',Color3.fromRGB(255,120,120)) end
		return false
	end
	local n=applyCfg(c)
	log('Config dimuat: '..n..' nilai.')
	showToast('📂 Config dimuat ('..n..')',Color3.fromRGB(120,255,160))
	return true
end
sect(pages['Lain'],'KONFIGURASI (simpan / muat ulang)')
tog(pages['Lain'],'Auto-load config saat script jalan','cfgAuto',function(on)
	if on then
		doSave()
		log('Auto-load AKTIF: config dipakai otomatis saat eksekusi/teleport berikutnya.')
	else
		log('Auto-load MATI: config tetap tersimpan, muat manual via tombol Load.')
	end
end)
btn(pages['Lain'],'💾 Save konfigurasi (tulis file)',doSave)
btn(pages['Lain'],'📂 Load konfigurasi (terapkan)',function() doLoad(false) end)
btn(pages['Lain'],'🗑 Hapus file konfigurasi',function()
	pcall(function() delfile(CFGPATH) end)
	log('File config dihapus.')
	showToast('🗑 Config dihapus',Color3.fromRGB(255,200,100))
end)
-- Boot: kalau config bilang Auto ON → langsung terapkan (tanpa klik apa pun).
task.spawn(function()
	task.wait(0.5)
	local ok,raw=pcall(function() return readfile(CFGPATH) end)
	if not ok or type(raw)~='string' or raw=='' then return end
	local ok2,c=pcall(function() return game:GetService('HttpService'):JSONDecode(raw) end)
	if not ok2 or type(c)~='table' or c.cfgAuto~=true then return end
	local n=applyCfg(c)
	log('Auto-load config: '..n..' nilai diterapkan.')
	showToast('📂 Config auto-load ('..n..')',Color3.fromRGB(120,255,160))
end)

-- Helper console: AAD_SET('espM',true) / AAD_GET() / AAD_SAVE() / AAD_LOAD()
ENV.AAD_SET=function(k,v) if S[k]==nil then return false end S[k]=v for _,p in ipairs(togPainters[k] or {}) do pcall(p) end if togCbs[k] then pcall(togCbs[k],v) end if k=='fly' then setFly(v) end return true end
ENV.AAD_GET=function() local c={} for k,v in pairs(S) do c[k]=v end return c end
ENV.AAD_SAVE=doSave
ENV.AAD_LOAD=function() return doLoad(false) end

print('[AAD] v2 Loaded by Alexander Jay (@absrdme)! Insert / RightShift = tampil/sembunyi. Tab Tempur: aimbot/triggerbot/ESP.')
