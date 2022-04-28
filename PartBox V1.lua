--=======================================PartBox v1.0==============================================
--@author: awzxd
--This is one of my first module , so I have doubts about its optimization =(

local TweenService = game:GetService("TweenService")
local Signal = require(game.ReplicatedStorage.Packages.Signal)

local DEFAULT_PART_FOLDER = workspace.Hitboxes or Instance.new("Folder", workspace)
DEFAULT_PART_FOLDER.Name = "Hitboxes"

local DEFAULT_PARAMS = OverlapParams.new()
DEFAULT_PARAMS.FilterType = Enum.RaycastFilterType.Blacklist

local Hitbox = {}
local prototype = {}

Hitbox.__index = prototype

local HitboxState = {
	NotStarted = "NotStarted",
	Started = "Started",
	Finished = "Finished",
	CallingChilds = "CallingChilds"
}

local formatString = "\n\tName: (%s)\tState: (%s)\tChilds(%s)\n"
local nameFormat = "%s's Child %d"

--======================================STATIC METHODS============================================

--[[
	@class Hitbox
	@static method CreateHitbox(data)
	
	parameter 'data' must be a dictionary:
	
	Time: number(opt) --> How long the hitbox will remain active.
	Attacker: Instance(opt) --> The player character who will handle the hitbox. If nil, the hitbox will be able to hit your owner.
	StopOnHit: boolean(opt) --> If the hitbox will be auto-destroyed after hitting something.
	CooldownHit: number(opt) --> Only used if StopOnHit is false. Defines the hit cooldown for each 'hit'.
	Visible: boolean(opt) --> Enables hitbox's visiblity
	Size: Vector3(required) --> The hitbox part Size property.
	CFrame: CFrame(required) --> The hitbox part CFrame property.
	Tween: dictionary(opt) --> A dictionary that will be used for tweening with the following format:
		Info: TweenInfo
		Data: PropertyDictionary
	
	WeldedPart: Instance(opt) --> A part the hitbox part will be welded to.
	AOE: boolean(opt) --> Enables Area of Effect of the hitbox.
	Touchable: array(opt) --> if not empty, the hitbox will be able to hit other part instances.
		Must be an array containing instances that will be ignored.
		Touchable is useless if StopOnHit is false
	
]]
function Hitbox.CreateHitbox(data)
	
	local self = {}
	
	self.Time = data.Time
	self.Attacker = data.Attacker
	self.StopOnHit = data.StopOnHit
	self.CooldownHit = data.CooldownHit
	self.Visible = data.Visible
	self.Size = data.Size
	self.CFrame = data.CFrame
	self.Tween = data.Tween
	self.WeldedPart = data.WeldedPart
	self.AOE = data.AOE
	self.Touchable = data.Touchable
	
	self.OnHit = Signal.new()
	self.Parent = data.Parent
	self._childs = {}; self._childsCount = 0;
	self._name = data.Name or "Part"
	self._state = HitboxState.NotStarted
	self._level = data.Level or 0;
	setmetatable(self, Hitbox)
	return self
end

function Hitbox.is(obj)
	return getmetatable(obj) == Hitbox and rawget(obj.StartTouched) ~= nil
end
--======================================OBJECT METHODS============================================

function prototype:_makeTween(info, data)
	return TweenService:Create(self.Part, info, data)
end

--[[
	@class Hitbox
	@method extend(data)
	data must be an array with the same format of 'CreateHitbox' parameter
	
	this function will extend your hitbox, allowing creating and linking a hitbox to
	be handled after the parent firing a hit.
	
]]
function prototype:extend(data)
	self._childsCount += 1;
	local length = #self._childs
	data.Parent = length == 0 and self or self._childs[length]
	data.Name = data.Name or nameFormat:format(self._name, #self._childs + 1)
	data.Level = self._childsCount
	if length == 0 then
		table.insert(self._childs, Hitbox.CreateHitbox(data))
		return
	end
	table.insert(self._childs[length]._childs, Hitbox.CreateHitbox(data))
end

--[[
	@class Hitbox
	@object method StartTouched()
	
	The initializer of the Hitbox.
	Each hit will fire a signal. This signal can be received by Connecting the 'OnHit' property.
	
]]
function prototype:StartTouched()
	self._state = HitboxState.Started
	
	local Part = Instance.new("Part")
	Part.Size = self.Size
	Part.CFrame = self.CFrame
	Part.Anchored = if self.WeldedPart then false else true
	Part.CanCollide = false
	Part.Transparency = self.Visible and .7 or 1
	Part.Color = Color3.fromRGB(255, 0, 0)
	Part.Massless = true
	Part.Parent = DEFAULT_PART_FOLDER
	self.Part = Part

	local function query(part, hum)
		local filteredResults = {}
		local Params = DEFAULT_PARAMS
		Params.FilterDescendantsInstances = {self.Attacker};
		local result = workspace:GetPartsInPart(part, Params)
		
		for _, v in ipairs(result) do
			local name = v.Parent.Name
			if name and not filteredResults[name] then
				local humanoid = v.Parent:FindFirstChildOfClass("Humanoid")
				if humanoid and humanoid.Health > 0 then
					filteredResults[name] = humanoid
				end
			end
		end
		
		return filteredResults
	end

	local function check(hum)
		return hum ~= self.Attacker.Humanoid
	end
	
	local function checkPart(part, partArray) --> Retorna true caso part for diferente das parts da array
		for _, parts in ipairs(partArray) do
			if parts == part then 
				return false
			end
		end
		return true
	end
	if self.WeldedPart then
		local Weld = Instance.new("WeldConstraint", self.Part)
		Weld.Part0 = self.Part
		Weld.Part1 = self.WeldedPart
	end
	if self.Tween then
		self:_makeTween(self.Tween.Info, self.Tween.Data):Play()
	end
	if self.StopOnHit then
		if self.Time then 
			coroutine.wrap(function()
				self.Time += os.clock()
				while self.Part do
					if os.clock() >= self.Time then
						self:Destroy()
						break
					end
				task.wait()
				end
			end)()
		end

		self.Connection = self.Part.Touched:Connect(function(part)
			if self.Touchable then
				if checkPart(part, self.Touchable) then
					self.OnHit:Fire({part}, self._level)
					self:Destroy()
					return
				end
			end
			local Model = part.Parent
			local Humanoid = Model and Model:FindFirstChildOfClass("Humanoid")
			if Model and Model:IsA("Model") and Humanoid then
				if self.AOE then
					local hums = query(self.Part)
					self.OnHit:Fire(hums, self._level)
					self:Destroy()
				elseif check(Humanoid) and Humanoid.Health > 0 then
					self.OnHit:Fire({Humanoid}, self._level)
					self:Destroy()
				end			
			end		
		end)
	else
		self.Time += os.clock()
		coroutine.wrap(function()
			while self.Part do
				if os.clock() > self.Time then
					print("Destroyed by Time")
					self:Destroy()
					return
				end
				local hums = query(self.Part)
				self.OnHit:Fire(hums, self._level)
				task.wait(self.CooldownHit)
			end
		end)()
	end
end

--[[
	@class Hitbox
	@method Destroy
	
	Destroys the object itself, Destroying their part and Signal.
	if it has childs, starts calling them.
	Note: A hitbox object will exist until it has no child.
	When a child has no child and get destroyed, your parents will be destroyed as well
]]
function prototype:Destroy()
	warn(self._name .. " Part Destroyed!")
	self.Part:Destroy()
	self.Part = nil
	if #self._childs > 0 then
		self._state = HitboxState.CallingChilds
		warn("Hitbox has a child, initializing it")
		self._childs[1].OnHit = self.OnHit
		self._childs[1]:StartTouched()
	else
		warn("No childs remaining. Destroying signals")
		local parent = self
		while parent do
			if parent.OnHit then
				warn(parent._name .. " Signal Destroyed")
				parent.OnHit:Destroy()
				parent._state = HitboxState.Finished
			end
			parent = parent.Parent
		end
	end
end

--[[
	@class Hitbox
	@method GetInfo
	
	returns information about the hitbox object. Returns your name, state and childs amount.
]]
function prototype:GetInfo()
	return formatString:format(self._name, self._state, #self._childs)
end

return Hitbox
