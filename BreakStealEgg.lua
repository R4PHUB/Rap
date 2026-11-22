--[[
	RapHub - Break and Steal an Egg
	Fitur:
	  - Teleport ke egg yang muncul (pilih manual / terdekat / auto)
	  - Teleport ke area (Zone1..ZoneN)
]]

local BASE_URL = "https://raw.githubusercontent.com/R4PHUB/Rap/refs/heads/main/"

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer

local Library = loadstring(game:HttpGet(BASE_URL .. "UI.lua"))()

---------------------------------------------------------------------
-- Setting
---------------------------------------------------------------------
local Settings = {
	TeleportMode = "Instant", -- "Instant" | "Tween"
	TweenSpeed = 120, -- stud per detik
	HeightOffset = 4, -- tinggi di atas target
	AutoDelay = 1, -- jeda antar teleport (detik) untuk auto
	AutoPrompt = false, -- otomatis tekan ProximityPrompt di dekat egg
	EggFilter = {}, -- kosong = semua egg
}

---------------------------------------------------------------------
-- Helper karakter & posisi
---------------------------------------------------------------------
local function GetRoot()
	local Character = Player.Character
	return Character and Character:FindFirstChild("HumanoidRootPart")
end

-- Ambil posisi tengah dari Model / BasePart / Folder
local function GetPosition(Object)
	if not Object or not Object.Parent then
		return nil
	end

	if Object:IsA("BasePart") then
		return Object.Position
	end

	if Object:IsA("Model") then
		local ok, cf = pcall(function()
			return Object:GetPivot()
		end)
		if ok and cf then
			return cf.Position
		end
	end

	-- Folder / lainnya: rata-rata posisi semua BasePart di dalamnya
	local Sum, Count = Vector3.zero, 0
	for _, Part in ipairs(Object:GetDescendants()) do
		if Part:IsA("BasePart") then
			Sum += Part.Position
			Count += 1
		end
	end

	return Count > 0 and Sum / Count or nil
end

-- Cari pijakan di bawah titik (biar tidak teleport ke dalam tanah / langit)
local function FindGround(Position)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Exclude
	Params.FilterDescendantsInstances = { Player.Character }

	local Result = workspace:Raycast(Position + Vector3.new(0, 60, 0), Vector3.new(0, -250, 0), Params)
	return Result and Result.Position or Position
end

local ActiveTween
local function TeleportTo(Position)
	local Root = GetRoot()
	if not Root or not Position then
		return false
	end

	local Target = CFrame.new(Position + Vector3.new(0, Settings.HeightOffset, 0))

	if ActiveTween then
		ActiveTween:Cancel()
		ActiveTween = nil
	end

	if Settings.TeleportMode == "Tween" then
		local Distance = (Root.Position - Target.Position).Magnitude
		local Duration = math.max(Distance / math.max(Settings.TweenSpeed, 1), 0.05)

		ActiveTween = TweenService:Create(Root, TweenInfo.new(Duration, Enum.EasingStyle.Linear), { CFrame = Target })
		ActiveTween:Play()
		ActiveTween.Completed:Wait()
		ActiveTween = nil
	else
		Root.CFrame = Target
	end

	Root.AssemblyLinearVelocity = Vector3.zero
	return true
end

local function FirePromptsNear(Object)
	if not fireproximityprompt or not Object then
		return
	end
	for _, Prompt in ipairs(Object:GetDescendants()) do
		if Prompt:IsA("ProximityPrompt") and Prompt.Enabled then
			pcall(fireproximityprompt, Prompt)
		end
	end
end

local function Notify(Title, Content)
	task.spawn(function()
		pcall(function()
			Library:SetNotification({
				Title = "RapHub",
				Description = Title,
				Content = Content,
				Delay = 3,
			})
		end)
	end)
end

---------------------------------------------------------------------
-- Egg
---------------------------------------------------------------------
-- Tempat egg yang muncul di map (lihat Explorer: Workspace.Eggs)
local function GetEggContainers()
	local List = {}
	local EggFolder = workspace:FindFirstChild("Eggs")
	if EggFolder then
		table.insert(List, EggFolder)
	end
	return List
end

-- Kumpulkan egg: Model/BasePart di dalam container (Folder ditelusuri lagi)
local function CollectEggs()
	local Eggs = {}

	local function Scan(Parent, Depth)
		for _, Child in ipairs(Parent:GetChildren()) do
			if Child:IsA("Model") or Child:IsA("BasePart") then
				table.insert(Eggs, Child)
			elseif (Child:IsA("Folder") or Child:IsA("Configuration")) and Depth < 3 then
				Scan(Child, Depth + 1)
			end
		end
	end

	for _, Container in ipairs(GetEggContainers()) do
		Scan(Container, 0)
	end

	return Eggs
end

local function EggPassesFilter(Egg)
	if #Settings.EggFilter == 0 then
		return true
	end
	return table.find(Settings.EggFilter, Egg.Name) ~= nil
end

local function GetNearestEgg(Exclude)
	local Root = GetRoot()
	if not Root then
		return nil
	end

	local Best, BestDist = nil, math.huge
	for _, Egg in ipairs(CollectEggs()) do
		if EggPassesFilter(Egg) and not (Exclude and Exclude[Egg]) then
			local Pos = GetPosition(Egg)
			if Pos then
				local Dist = (Pos - Root.Position).Magnitude
				if Dist < BestDist then
					Best, BestDist = Egg, Dist
				end
			end
		end
	end
	return Best
end

local function TeleportToEgg(Egg)
	local Pos = GetPosition(Egg)
	if not Pos then
		return false
	end
	local ok = TeleportTo(Pos)
	if ok and Settings.AutoPrompt then
		task.wait(0.2)
		FirePromptsNear(Egg)
	end
	return ok
end

-- Nama semua jenis egg (yang sedang muncul + dari ReplicatedStorage.Eggs)
local function GetEggTypeNames()
	local Names, Seen = {}, {}

	local function Add(Name)
		if not Seen[Name] then
			Seen[Name] = true
			table.insert(Names, Name)
		end
	end

	for _, Egg in ipairs(CollectEggs()) do
		Add(Egg.Name)
	end

	local RSEggs = ReplicatedStorage:FindFirstChild("Eggs")
	if RSEggs then
		for _, Obj in ipairs(RSEggs:GetDescendants()) do
			if Obj:IsA("Model") and Obj.Parent and not Obj.Parent:IsA("Model") then
				Add(Obj.Name)
			end
		end
	end

	table.sort(Names)
	return Names
end

---------------------------------------------------------------------
-- Area / Zone
---------------------------------------------------------------------
local function GetZones()
	local Zones = {}
	local Build = workspace:FindFirstChild("Build")
	local ZoneBuilds = Build and Build:FindFirstChild("ZoneBuilds")
	local ZoneHitboxes = Build and Build:FindFirstChild("ZoneHitboxes")

	local Source = ZoneBuilds or ZoneHitboxes
	if not Source then
		return Zones
	end

	for _, Zone in ipairs(Source:GetChildren()) do
		table.insert(Zones, Zone.Name)
	end

	-- Urutkan berdasarkan angka (Zone2 sebelum Zone10)
	table.sort(Zones, function(a, b)
		local na, nb = tonumber(a:match("%d+")), tonumber(b:match("%d+"))
		if na and nb and na ~= nb then
			return na < nb
		end
		return a < b
	end)

	return Zones
end

local function GetZonePosition(ZoneName)
	local Build = workspace:FindFirstChild("Build")
	if not Build then
		return nil
	end

	local ZoneBuilds = Build:FindFirstChild("ZoneBuilds")
	local Zone = ZoneBuilds and ZoneBuilds:FindFirstChild(ZoneName)

	if Zone then
		-- Prioritas: area egg di zona itu (tempat utama), lalu tengah zona
		local Target = Zone:FindFirstChild("Eggs") or Zone
		local Pos = GetPosition(Target)
		if Pos then
			return FindGround(Pos)
		end
	end

	local ZoneHitboxes = Build:FindFirstChild("ZoneHitboxes")
	local Hitbox = ZoneHitboxes and ZoneHitboxes:FindFirstChild(ZoneName)
	local Pos = GetPosition(Hitbox)
	return Pos and FindGround(Pos) or nil
end

---------------------------------------------------------------------
-- UI
---------------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "RapHub",
	Description = "Break and Steal an Egg",
	["Tab Width"] = 120,
})

local MainTab = Window:CreateTab({ Name = "Teleport", Icon = "" })
local SettingTab = Window:CreateTab({ Name = "Settings", Icon = "" })

-- ===== Egg Teleport =====
local EggSection = MainTab:AddSection("Egg Teleport", true)

local EggInfo = EggSection:AddParagraph({
	Title = "Egg di map",
	Content = "Menghitung...",
})

local EggMap = {} -- teks dropdown -> instance egg
local SelectedEgg = nil

local function BuildEggList()
	EggMap = {}
	local Root = GetRoot()
	local List = {}
	local Counter = {}

	for _, Egg in ipairs(CollectEggs()) do
		if EggPassesFilter(Egg) then
			Counter[Egg.Name] = (Counter[Egg.Name] or 0) + 1
			local Label = Egg.Name .. " #" .. Counter[Egg.Name]

			local Pos = GetPosition(Egg)
			if Root and Pos then
				Label = Label .. string.format(" (%dm)", math.floor((Pos - Root.Position).Magnitude))
			end

			EggMap[Label] = Egg
			table.insert(List, Label)
		end
	end

	return List
end

local EggDropdown = EggSection:AddDropdown({
	Title = "Pilih Egg",
	Content = "Egg yang sedang muncul",
	Multi = false,
	Options = {},
	Default = {},
	Callback = function(Value)
		SelectedEgg = Value and Value[1] and EggMap[Value[1]] or nil
	end,
})

local function RefreshEggs()
	local List = BuildEggList()
	EggDropdown:Refresh(List, {})
	SelectedEgg = nil
	EggInfo:Set({
		Title = "Egg di map",
		Content = #List .. " egg ditemukan" .. (#Settings.EggFilter > 0 and " (pakai filter)" or ""),
	})
end

EggSection:AddButton({
	Title = "Refresh Daftar Egg",
	Content = "Muat ulang egg yang muncul",
	Callback = RefreshEggs,
})

EggSection:AddButton({
	Title = "Teleport ke Egg Terpilih",
	Content = "Teleport ke egg di dropdown",
	Callback = function()
		if SelectedEgg and SelectedEgg.Parent then
			TeleportToEgg(SelectedEgg)
		else
			Notify("Egg", "Egg tidak ada / sudah hilang, refresh dulu.")
			RefreshEggs()
		end
	end,
})

EggSection:AddButton({
	Title = "Teleport ke Egg Terdekat",
	Content = "Langsung ke egg paling dekat",
	Callback = function()
		local Egg = GetNearestEgg()
		if Egg then
			TeleportToEgg(Egg)
		else
			Notify("Egg", "Tidak ada egg yang cocok saat ini.")
		end
	end,
})

local AutoEgg = false
EggSection:AddToggle({
	Title = "Auto Teleport Egg Baru",
	Content = "Otomatis pindah ke tiap egg yang muncul",
	Default = false,
	Callback = function(Value)
		AutoEgg = Value
	end,
})

-- ===== Filter Egg =====
local FilterSection = MainTab:AddSection("Filter Egg", false)

local FilterDropdown = FilterSection:AddDropdown({
	Title = "Jenis Egg",
	Content = "Kosong = semua egg",
	Multi = true,
	Options = GetEggTypeNames(),
	Default = {},
	Callback = function(Value)
		Settings.EggFilter = Value or {}
	end,
})

FilterSection:AddButton({
	Title = "Refresh Jenis Egg",
	Content = "Muat ulang nama-nama egg",
	Callback = function()
		FilterDropdown:Refresh(GetEggTypeNames(), Settings.EggFilter)
	end,
})

-- ===== Area Teleport =====
local AreaSection = MainTab:AddSection("Area Teleport", true)

local SelectedZone = nil
local ZoneDropdown = AreaSection:AddDropdown({
	Title = "Pilih Area",
	Content = "Zona di map",
	Multi = false,
	Options = GetZones(),
	Default = {},
	Callback = function(Value)
		SelectedZone = Value and Value[1] or nil
	end,
})

AreaSection:AddButton({
	Title = "Teleport ke Area",
	Content = "Pindah ke area yang dipilih",
	Callback = function()
		if not SelectedZone then
			Notify("Area", "Pilih area dulu.")
			return
		end
		local Pos = GetZonePosition(SelectedZone)
		if Pos then
			TeleportTo(Pos)
		else
			Notify("Area", "Posisi " .. SelectedZone .. " tidak ditemukan.")
		end
	end,
})

AreaSection:AddButton({
	Title = "Refresh Area",
	Content = "Muat ulang daftar zona",
	Callback = function()
		ZoneDropdown:Refresh(GetZones(), {})
		SelectedZone = nil
	end,
})

-- ===== Settings =====
local TpSection = SettingTab:AddSection("Teleport", true)

TpSection:AddDropdown({
	Title = "Mode Teleport",
	Content = "Instant atau Tween (lebih halus)",
	Multi = false,
	Options = { "Instant", "Tween" },
	Default = { "Instant" },
	Callback = function(Value)
		Settings.TeleportMode = Value and Value[1] or "Instant"
	end,
})

TpSection:AddSlider({
	Title = "Kecepatan Tween",
	Content = "Stud per detik",
	Increment = 10,
	Min = 30,
	Max = 500,
	Default = Settings.TweenSpeed,
	Callback = function(Value)
		Settings.TweenSpeed = Value
	end,
})

TpSection:AddSlider({
	Title = "Tinggi Offset",
	Content = "Jarak di atas target",
	Increment = 1,
	Min = 0,
	Max = 20,
	Default = Settings.HeightOffset,
	Callback = function(Value)
		Settings.HeightOffset = Value
	end,
})

TpSection:AddSlider({
	Title = "Jeda Auto Teleport",
	Content = "Detik antar egg",
	Increment = 1,
	Min = 0,
	Max = 10,
	Default = Settings.AutoDelay,
	Callback = function(Value)
		Settings.AutoDelay = Value
	end,
})

TpSection:AddToggle({
	Title = "Auto Tekan Prompt",
	Content = "Tekan ProximityPrompt egg setelah teleport (butuh executor yang support)",
	Default = false,
	Callback = function(Value)
		Settings.AutoPrompt = Value
	end,
})

---------------------------------------------------------------------
-- Loop
---------------------------------------------------------------------
RefreshEggs()

-- Auto teleport: datangi tiap egg sekali, lanjut ke egg baru yang muncul
task.spawn(function()
	local Visited = setmetatable({}, { __mode = "k" })

	while not Library.Unloaded do
		if AutoEgg then
			local Egg = GetNearestEgg(Visited)
			if Egg then
				Visited[Egg] = true
				TeleportToEgg(Egg)
				task.wait(Settings.AutoDelay)
			else
				task.wait(0.5)
			end
		else
			table.clear(Visited)
			task.wait(0.5)
		end
	end
end)

-- Update jumlah egg secara berkala
task.spawn(function()
	while not Library.Unloaded do
		task.wait(3)
		local Count = 0
		for _, Egg in ipairs(CollectEggs()) do
			if EggPassesFilter(Egg) then
				Count += 1
			end
		end
		pcall(function()
			EggInfo:Set({
				Title = "Egg di map",
				Content = Count .. " egg ditemukan" .. (#Settings.EggFilter > 0 and " (pakai filter)" or ""),
			})
		end)
	end
end)

Notify("Loaded", "Break and Steal an Egg siap dipakai!")
