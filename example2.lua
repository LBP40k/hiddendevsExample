--Discord Username : lbplan, Roblox Username : Littlebigplanet40000

--This script is a skillset module to be used with the combat system

--Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")




--Assets
local VFX = ReplicatedStorage.Assets.VFX
local Slash = VFX.Shockwave

--Constants
local External = ReplicatedStorage.External
local SETTINGS = {
	FIST_DAMAGE = 10,
	FIST_KNOCKBACK = 1000,
	GROUND_SLAM_DAMAGE = 20,
	MIN_BLOCK_SIZE = 1,
	MAX_BLOCK_SIZE = 3,
	ROCK_AMOUNT = 3
}

--Modules
local MuchachoHitbox = require(External.MuchachoHitbox)
local DamageModule = require(ReplicatedStorage.Shared.DamageModule)

--Helper Functions

function playAnimation(character, animationId)
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then return end

	local animator = humanoid:FindFirstChild("Animator")
	if not animator then return end
	
	local animation = Instance.new("Animation")
	animation.AnimationId = "rbxassetid://" .. animationId
	local track : AnimationTrack = animator:LoadAnimation(animation)
	track:Play()
	
	track.Ended:Once(function()
		animation:Destroy()
	end)
	return track
end


--Slows the player down for a given duration
function ApplyStun(character, duration)
	local humanoid = character.Humanoid

	local originalSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0

	task.delay(duration,function()
		humanoid.WalkSpeed = originalSpeed
	end)
end


--This function creates a trail of rocks at a given position, direction and distance
function CreateRockTrail(position, direction, distance)
	
	for i = 0, distance, 1 do
		for amount = 0, SETTINGS.ROCK_AMOUNT, 1 do
			local rock = Instance.new("Part")
			rock.Size = Vector3.new(math.random(SETTINGS.MIN_BLOCK_SIZE,SETTINGS.MAX_BLOCK_SIZE),math.random(SETTINGS.MIN_BLOCK_SIZE,SETTINGS.MAX_BLOCK_SIZE),math.random(SETTINGS.MIN_BLOCK_SIZE,SETTINGS.MAX_BLOCK_SIZE))
			rock.Position = position + (direction * i) + Vector3.new(math.random(-2,2), math.random(-2,2), math.random(-2,2))
			rock.Orientation = Vector3.new(math.random(0,360),math.random(0,360),math.random(0,360))
			rock.Anchored = true
			rock.Material = Enum.Material.Concrete
			rock.Color = Color3.fromRGB(100, 100, 100)
			rock.Anchored = true
			rock.CanCollide = false
			rock.Parent = workspace
			task.wait(0.01)
			Debris:AddItem(rock,1.5)
		end
		
	end
end
	

--This functions create a debris of rocks at a given position
local function CreateGroundDebris(position)

	--Raycast downs to find the ground
	local result = workspace:Raycast(
		position + Vector3.new(0, 5, 0),
		Vector3.new(0, -15, 0),
	)

	if not result then
		return
	end

	for i = 1, 6 do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(
			math.random(1, 3),
			math.random(1, 3),
			math.random(1, 3)
		)
	
	
		--Sets the chunks material and color to the ground material and color
		chunk.Material = result.Material
		chunk.Color = result.Instance.Color

		chunk.Anchored = false
		chunk.CanCollide = false

		chunk.CFrame =
			CFrame.new(result.Position)
			* CFrame.new(
				math.random(-3,3),
				0,
				math.random(-3,3)
			)

		chunk.Parent = workspace
		
		
		
		local velocity = Instance.new("BodyVelocity")
		velocity.MaxForce = Vector3.new(math.huge,math.huge,math.huge)

		--Gives the chunks a random velocity
		local randomDirection =
			Vector3.new(
				math.random(-10,10),
				math.random(15,25),
				math.random(-10,10)
			)

		velocity.Velocity = randomDirection
		velocity.Parent = chunk

		Debris:AddItem(velocity,0.15)

		task.delay(0.5,function()
			TweenService:Create(
				chunk,
				TweenInfo.new(0.5),
				{
					Transparency = 1,
					Size = Vector3.zero
				}
			):Play()
		end)

		Debris:AddItem(chunk,1)
	end
end

--Skillset Moves
return {
	[1] = {
		Name = "Fists",
		Cooldown = 0.25,
		Use = function(combat)
			local Player = combat.Player
			local Character = Player.Character
			local RootPart = Character.HumanoidRootPart
			
			--Uses the MuchahoHitbox module to create a hitbox in front of the player
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {Character}
			
			local hitbox = MuchachoHitbox.CreateHitbox()
			hitbox.Size = Vector3.new(5, 5, 5)
			hitbox.DetectionMode = "HitOnce"
			hitbox.CFrame = RootPart.CFrame * CFrame.new(0, 0, -3)
			hitbox.OverlapParams = params
			hitbox.Visualizer = false
			
			local anim : AnimationTrack = playAnimation(Character,76757989424716)
			
			hitbox.Touched:Connect(function(hit, humanoid)
				if humanoid == Character.Humanoid then return end
				
				combat.Combo+= 1	
				
				--This is to make the fist animation change based on the combo (hits with left arm then right then left etc..)
				if combat.Combo % 2 == 0 then
					anim:Stop()
					playAnimation(Character,108895984374395)	
				end
				
				--Checks if combo is divisible evenly by 3, if it is then it will do more damage and knockback and add a rock trail
				if combat.Combo % 3 == 0 then
					DamageModule.Damage(humanoid.Parent,SETTINGS.FIST_DAMAGE*1.5)
					
					
					combat:ApplyKnockback(humanoid.Parent, SETTINGS.FIST_KNOCKBACK * 1.5)
					CreateRockTrail(humanoid.Parent.HumanoidRootPart.Position - Vector3.new(0,3,0), RootPart.CFrame.LookVector, 10)
				else
					DamageModule.Damage(humanoid.Parent,SETTINGS.FIST_DAMAGE)
					
					combat:ApplyKnockback(humanoid.Parent, SETTINGS.FIST_KNOCKBACK)
					CreateGroundDebris(humanoid.Parent.HumanoidRootPart.Position - Vector3.new(0,6,0))
					
				end
			end)
			
			hitbox:Start()
			
		end
	},
	[2] = {
		Name = "Dash",
		Cooldown = 1,
		Use = function(combat)
			local Player = combat.Player
			local Character = Player.Character
			local RootPart = Character.HumanoidRootPart
			
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = RootPart.CFrame.LookVector * 100
			bv.MaxForce = Vector3.new(10000,10000,10000)
			bv.Parent = RootPart
			game.Debris:AddItem(bv,0.1)
		end
	},
	[3] = {
		Name = "Ground Slam",
		Cooldown = 3,
		Use = function(combat)
			local Player = combat.Player
			local Character = Player.Character
			local RootPart = Character.HumanoidRootPart
			
			--Launches player in the air
			local bv = Instance.new("BodyVelocity")
			bv.Velocity = Vector3.new(0,100,0)
			bv.MaxForce = Vector3.new(10000,10000,10000)
			bv.Parent = RootPart
			Debris:AddItem(bv,0.1)
			
			
			--Waits a delay period before waiting until the player hits the ground by using the .FloorMaterial property of the humanoid
			task.delay(0.5,function()
				repeat wait() until Character.Humanoid.FloorMaterial ~= Enum.Material.Air
				
				local slashEffect = Slash:Clone()
				slashEffect.Parent = workspace
				slashEffect.CFrame = RootPart.CFrame * CFrame.new(0,-2.5,0)
				Debris:AddItem(slashEffect,1)
				local targetCFrame =
					slashEffect.CFrame
					* CFrame.new(0,0,-100)

				local properties = {
					CFrame = targetCFrame,
					Size = slashEffect.Size * 20,
					Transparency = 1
				}
				local tween = TweenService:Create(slashEffect,TweenInfo.new(0.5),properties):Play()
				
				
				for _,v in pairs(workspace:GetChildren()) do
					if v:FindFirstChild("Humanoid") then
						if v == Character then continue end
						local humanoid = v:FindFirstChild("Humanoid")
						
						local rootPart = v:FindFirstChild("HumanoidRootPart")
						if (rootPart.Position - RootPart.Position).Magnitude < 50 then
							DamageModule.Damage(humanoid.Parent,SETTINGS.GROUND_SLAM_DAMAGE)
							
							--Gets the direction of the enemy compared to the player and applies knockback in that direction
							local direction = (rootPart.Position - RootPart.Position).Unit
							local knockback = direction * 100 + Vector3.new(0,60,0)
							rootPart.Velocity = knockback
							ApplyStun(v,1)
						end
					end
				end
			end)
		end
	}
}
