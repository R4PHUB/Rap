local VERSION = "1.1"
local HUB_NAME = "RapHub"
local REPO = "R4PHUB/all-game"
local games = {
	[10765288803] = "break-steal-egg.lua",
}

local HttpService = game:GetService("HttpService")

local universeId = game.GameId
local placeId = game.PlaceId
local scriptFile = games[universeId] or games[placeId]

print(string.format("[%s v%s] PlaceId: %d | UniverseId: %d", HUB_NAME, VERSION, placeId, universeId))

-- Ambil commit terbaru, lalu muat file dari commit itu (raw per-commit tidak pernah basi oleh cache).
-- Kalau API GitHub gagal (mis. limit), pakai URL branch biasa + penanda waktu.
local function ResolveUrl(File)
	local ok, Body = pcall(function()
		return game:HttpGet("https://api.github.com/repos/" .. REPO .. "/commits/main")
	end)
	if ok and type(Body) == "string" then
		local ok2, Data = pcall(function()
			return HttpService:JSONDecode(Body)
		end)
		local Sha = ok2 and type(Data) == "table" and Data.sha
		if type(Sha) == "string" and #Sha >= 7 then
			return "https://raw.githubusercontent.com/" .. REPO .. "/" .. Sha .. "/" .. File
		end
	end
	return "https://raw.githubusercontent.com/" .. REPO .. "/refs/heads/main/" .. File .. "?t=" .. tostring(os.time())
end

if scriptFile then
	print(string.format("[%s] Game supported! UniverseId: %d", HUB_NAME, universeId))
	print(string.format("[%s] Loading script...", HUB_NAME))

	local ok, err = pcall(function()
		loadstring(game:HttpGet(ResolveUrl(scriptFile)))()
	end)

	if not ok then
		warn(string.format("[%s] Gagal load script: %s", HUB_NAME, tostring(err)))
	end
else
	local msg = string.format("\n[%s] Game belum didukung!\nPlaceId: %d\nUniverseId: %d!", HUB_NAME, placeId, universeId)
	warn(msg)
	print(msg)
end
