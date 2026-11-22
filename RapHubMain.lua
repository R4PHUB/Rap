--[[
	RapHub Loader
	loadstring(game:HttpGet("https://raw.githubusercontent.com/R4PHUB/Rap/refs/heads/main/RapHubMain.lua"))()
]]

local BASE_URL = "https://raw.githubusercontent.com/R4PHUB/Rap/refs/heads/main/"

-- Daftar game: isi dengan PlaceId atau GameId (Universe Id) -> nama file script
local Games = {
	-- [1234567890] = "BreakStealEgg.lua",
}

-- Deteksi berdasarkan isi map (dipakai kalau ID belum diisi di atas)
local Detectors = {
	{
		File = "BreakStealEgg.lua",
		Check = function()
			local Build = workspace:FindFirstChild("Build")
			local RS = game:GetService("ReplicatedStorage")
			return Build ~= nil
				and Build:FindFirstChild("ZoneBuilds") ~= nil
				and workspace:FindFirstChild("Eggs") ~= nil
				and RS:FindFirstChild("Eggs") ~= nil
		end,
	},
}

local function Load(File)
	local ok, err = pcall(function()
		loadstring(game:HttpGet(BASE_URL .. File))()
	end)
	if not ok then
		warn("[RapHub] Gagal memuat " .. File .. ": " .. tostring(err))
	end
end

local File = Games[game.PlaceId] or Games[game.GameId]

if not File then
	for _, Detector in ipairs(Detectors) do
		local ok, match = pcall(Detector.Check)
		if ok and match then
			File = Detector.File
			break
		end
	end
end

if File then
	Load(File)
else
	warn(("[RapHub] Game belum didukung. PlaceId: %d | GameId: %d"):format(game.PlaceId, game.GameId))
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = "RapHub",
			Text = "Game ini belum didukung.",
			Duration = 5,
		})
	end)
end
