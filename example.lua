local MayorService = {}
local Players = game:GetService("Players")

local GameState = require(game.ServerScriptService.Server.GameState)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MayorRemote = ReplicatedStorage.Remotes.MayorRemote
local PoliceRemote = ReplicatedStorage.Remotes.PoliceRemote

local ElectionData = ReplicatedStorage.Data.ElectionData

local Voting = ElectionData:WaitForChild("Voting")
local VotingTime = ElectionData:WaitForChild("Time")

MayorService.ElectionInterval = 60*3
MayorService.VotingTime = 2

MayorService.NextElection = 1

MayorService.ElectionTimer = 0
MayorService.Voting = false

MayorService.PoliceForce = {}

local NotificationService = require(game.ServerScriptService.Server.Modules.NotificationService)
local CrimeService = require(game.ServerScriptService.Server.Modules.CrimeService)
local HousingService = require(game.ServerScriptService.Server.Modules.HousingService)

MayorService.Votes = {}

local PoliceForceFolder = ReplicatedStorage.Data.PoliceForce


function MayorService.GetVotesForCandidate(candidate)
	local count = 0
	for player, vote in pairs(MayorService.Votes) do
		if vote == candidate then
			count += 1
		end
	end
	return count
end

function MayorService.GetWinningCandidate()
	local candidates = Players:GetPlayers()

	local winner = nil
	local maxVotes = -1

	for _, player in ipairs(candidates) do
		local votes = MayorService.GetVotesForCandidate(player)

		if votes > maxVotes then
			maxVotes = votes
			winner = player
		end
	end

	return winner or (candidates[1])
end

function MayorService.StartElection()
	MayorService.Votes = {}
end

function MayorService.Vote(player, candidate)
	if MayorService.Voting then
		MayorService.Votes[player] = candidate
	end
end


function MayorService.ElectMayor(player)
	if GameState.Mayor and GameState.Mayor.Character then
		local oldTitle = GameState.Mayor.Character:FindFirstChild("MayorTitle")
		if oldTitle then
			oldTitle:Destroy()
		end
	end
	
	if GameState.Mayor then
		MayorRemote:InvokeClient(GameState.Mayor, "DeElect")
	end
	

	if not player or not player.Character then return end

	local newTitle = ReplicatedStorage.Assets.UI.TitleGui:Clone()
	newTitle.Name = "MayorTitle"
	newTitle.Label.Text = "Mayor"
	newTitle.Parent = player.Character

	MayorService.NextElection = MayorService.ElectionInterval
	MayorService.Voting = false
	GameState.Mayor = player

	NotificationService.SendGlobalNotification(
		"New Mayor: " .. player.Name,
		Color3.fromRGB(255, 255, 0)
	)

	MayorRemote:InvokeClient(player, "Elect")
end


function MayorService.AddPoliceForce(player)
	if not player.Character then return end

	local handcuffs = ReplicatedStorage.Assets.Models.Handcuffs:Clone()
	handcuffs.Parent = player.Backpack

	local title = ReplicatedStorage.Assets.UI.TitleGui:Clone()
	title.Name = "PoliceTitle"
	title.Label.Text = "Police"
	title.Label.TextColor3 = Color3.fromRGB(0, 0, 255)
	title.Parent = player.Character

	PoliceRemote:InvokeClient(player, "Recruit", {Handcuffs = handcuffs})
end

function MayorService.RemovePoliceForce(player)
	local handcuffs = player.Backpack:FindFirstChild("Handcuffs")
		or (player.Character and player.Character:FindFirstChild("Handcuffs"))

	if handcuffs then
		handcuffs:Destroy()
	end

	if player.Character then
		local title = player.Character:FindFirstChild("PoliceTitle")
		if title then
			title:Destroy()
		end
	end
end


function MayorService:Init()

	MayorRemote.OnServerInvoke = function(player, action, args)

		if action == "Vote" then
			MayorService.Vote(player, args.Candidate)
		end

		if action == "GetVotes" then
			return MayorService.GetVotesForCandidate(args.Candidate)
		end

		if action == "SetPolicy" then
			if player ~= GameState.Mayor then return end

			local policy = args.Policy

			if policy == "TaxRate" then
				if args.Value < 0 or args.Value > 1 then
					return GameState.TaxRate
				end

				GameState.TaxRate = args.Value

				NotificationService.SendGlobalNotification(
					"New Tax Rate: " .. GameState.TaxRate,
					Color3.fromRGB(255, 255, 0)
				)

				return GameState.TaxRate
			end

			if policy == "HouseCost" then
				if args.Value < 0 or args.Value > 100000 then
					return HousingService.HouseCost
				end

				HousingService.UpdateHouseCost(args.Value)

				NotificationService.SendGlobalNotification(
					"New House Price: " .. HousingService.HouseCost,
					Color3.fromRGB(255, 255, 0)
				)

				return HousingService.HouseCost
			end
		end

		if action == "GetPolicy" then
			local policy = args.Policy

			if policy == "TaxRate" then
				return GameState.TaxRate
			end

			if policy == "HouseCost" then
				return HousingService.HouseCost
			end
		end

		if action == "ToggleForce" then
			if player ~= GameState.Mayor then return end

			local target = args.Player
			if not target then return end

			MayorService.PoliceForce[target] = not MayorService.PoliceForce[target]

			local folder = PoliceForceFolder:FindFirstChild(target.Name)
			if folder then
				folder.Value = MayorService.PoliceForce[target]
			end

			if MayorService.PoliceForce[target] then
				MayorService.AddPoliceForce(target)
			else
				MayorService.RemovePoliceForce(target)
			end

			return MayorService.PoliceForce[target]
		end
	end

	
	task.spawn(function()
		while task.wait(1) do

			if MayorService.NextElection <= 0 and not MayorService.Voting then
				MayorService.NextElection = 0
				MayorService.ElectionTimer = MayorService.VotingTime
				MayorService.StartElection()
				MayorService.Voting = true
			end

			if MayorService.Voting then
				MayorService.ElectionTimer -= 1
			else
				MayorService.NextElection -= 1
			end

			if MayorService.ElectionTimer <= 0 and MayorService.Voting then
				local newMayor = MayorService.GetWinningCandidate()
				MayorService.ElectMayor(newMayor)
			end

			Voting.Value = MayorService.Voting
			VotingTime.Value = MayorService.Voting and MayorService.ElectionTimer or MayorService.NextElection
		end
	end)

	
	Players.PlayerAdded:Connect(function(player)
		MayorService.PoliceForce[player] = false

		local bool = Instance.new("BoolValue")
		bool.Name = player.Name
		bool.Value = false
		bool.Parent = PoliceForceFolder
	end)

	
	Players.PlayerRemoving:Connect(function(player)
		MayorService.PoliceForce[player] = nil

		local folder = PoliceForceFolder:FindFirstChild(player.Name)
		if folder then folder:Destroy() end

		if player == GameState.Mayor then
			local players = Players:GetPlayers()
			if #players > 0 then
				MayorService.ElectMayor(players[1])
			end
		end
	end)

	PoliceRemote.OnServerInvoke = function(player, action, args)

		if action == "Arrest" then

			if not MayorService.PoliceForce[player] then return end

			local target = Players:GetPlayerFromCharacter(args.Player)
			
			
			if not target then return end

			if target == GameState.Mayor then return end
			if MayorService.PoliceForce[target] == true then return end

			if not player.Character or not target.Character then return end

			CrimeService.AddSentence(target, 30)
			CrimeService.CollectWanted(target, player)
		end
	end
end

return MayorService
