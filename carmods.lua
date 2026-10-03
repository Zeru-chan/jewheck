# Full crеdits to adam (_blahaj) from ЕRХ
repeat task.wait() until getgenv().JHK and getgenv().JHK.Addons

if getgenv().CarModsLoaded then
    JHK:Notify("Car Mods", "Already loaded", 3, "small", "bell")
    return
end
getgenv().CarModsLoaded = true

local players = game:GetService("Players")
local runService = game:GetService("RunService")
local userInputService = game:GetService("UserInputService")
local replicatedStorage = game:GetService("ReplicatedStorage")
local lighting = game:GetService("Lighting")
local guiService = game:GetService("GuiService")
local lp = players.LocalPlayer

local Functions = {}

Functions.getChar = function()
    return lp.Character or lp.CharacterAdded:Wait()
end

Functions.getPlayerCar = function()
    local char = Functions.getChar()
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.SeatPart then
        local seat = char.Humanoid.SeatPart
        if seat:IsA("VehicleSeat") or seat.Name == "DriverSeat" then
            return seat.Parent
        end
    end
    if workspace:FindFirstChild("Vehicles") then
        for _, car in workspace.Vehicles:GetChildren() do
            if car:GetAttribute("Owner") == lp.Name then
                return car
            end
        end
    end
    if workspace:FindFirstChild("ATVs") then
        for _, atv in workspace.ATVs:GetChildren() do
            if atv:GetAttribute("Owner") == lp.Name then
                return atv
            end
        end
    end
    return JHK:OwnedCar() or JHK:OwnedATV()
end

Functions.isPlayerInOwnCar = function()
    local char = Functions.getChar()
    if not char or not char:FindFirstChild("Humanoid") then return false end
    local seat = char.Humanoid.SeatPart
    if seat and seat.Parent and seat.Parent:GetAttribute("Owner") == lp.Name then
        return true
    end
    return false
end

Functions.isDriving = function()
    return JHK:IsDriving()
end

Functions.togglePlayerCar = function(status)
    local gameGui = lp.PlayerGui:FindFirstChild("GameGui")
    if not gameGui then return false end
    local vehicleGui = gameGui:FindFirstChild("VehicleGui")
    if not vehicleGui then return false end
    local interface = vehicleGui:FindFirstChild("Vehicle Interface")
    if interface and interface:FindFirstChild("IsOn") then
        interface.IsOn.Value = status
        return true
    end
    return false
end

Functions.getController = function()
    local car = Functions.getPlayerCar()
    if not car then return nil end
    local module = car:FindFirstChild("Drive Controller")
    if not module then return nil end
    local ok, ctrl = pcall(require, module)
    return ok and ctrl or nil
end

local weights, saved, weightsCar = {}, {}, nil
Functions.makeWeightlessCar = function(toggle)
    local car = Functions.getPlayerCar()
    if not car or (not toggle and next(saved) == nil) then return false end
    if weightsCar ~= car and not toggle then
        weightsCar, weights, saved = nil, {}, {}
        return false
    end
    weightsCar = car
    local body = car:FindFirstChild("Body")
    if not body then return false end
    for _, item in body:GetChildren() do
        if item:IsA("BasePart") then
            if toggle then
                if not saved[item] then
                    saved[item] = true
                    weights[item] = item.CustomPhysicalProperties
                end
                local old = item.CurrentPhysicalProperties
                item.CustomPhysicalProperties = PhysicalProperties.new(0, old.Friction, old.Elasticity, old.FrictionWeight, old.ElasticityWeight)
            else
                if weights[item] then
                    item.CustomPhysicalProperties = weights[item]
                end
            end
        end
    end
    if not toggle then
        weightsCar, weights, saved = nil, {}, {}
    end
    return true
end

Functions.applyCamber = function(wheel, camber)
    if not wheel:FindFirstChild("AxleP") then return end
    local sideLetter = string.sub(wheel.Name, 2, 2)
    local isRight = (sideLetter == "R")
    local aa = wheel.AxleP:FindFirstChild("AA")
    local ba = wheel.AxleP:FindFirstChild("BA")
    if not aa or not ba then return end
    local radians = math.rad(camber)
    local yMultiplier = isRight and -1 or 1
    local y = math.cos(radians) * yMultiplier
    local z = math.sin(radians) * yMultiplier
    local newAxis = Vector3.new(0, y, z)
    aa.Axis = newAxis
    ba.Axis = newAxis
end

local weldCache = {}
local function ensureCache(wheel)
    local cached = weldCache[wheel]
    if cached and (not cached.weld or not cached.weld.Parent) then
        weldCache[wheel] = nil
        cached = nil
    end
    if not cached then
        local sa = wheel:FindFirstChild("#SA")
        if not sa then return nil end
        local car = Functions.getPlayerCar()
        if not car then return nil end
        local seat = car:FindFirstChild("DriverSeat")
        if not seat then return nil end
        local weld
        for _, child in seat:GetChildren() do
            if child:IsA("Weld") and child.Part1 == sa then
                weld = child
                break
            end
        end
        if not weld then return nil end
        cached = {
            weld = weld,
            origLocal = weld.C0 * weld.C1:Inverse(),
            offsets = { X = 0, Y = 0, Z = 0 },
        }
        weldCache[wheel] = cached
    end
    return cached
end

Functions.applyAxleOffset = function(wheel, offsets)
    local cached = ensureCache(wheel)
    if not cached then return end
    if offsets.X ~= nil then cached.offsets.X = offsets.X end
    if offsets.Y ~= nil then cached.offsets.Y = offsets.Y end
    if offsets.Z ~= nil then cached.offsets.Z = offsets.Z end
    local isRight = (string.sub(wheel.Name, 2, 2) == "R")
    local wm = isRight and 1 or -1
    local delta = Vector3.new(cached.offsets.X * wm, cached.offsets.Y, cached.offsets.Z)
    local newLocal = cached.origLocal + delta
    cached.weld.C1 = newLocal:Inverse() * cached.weld.C0
end

Functions.setWheelWorldPosition = function(wheel, worldPosition)
    local cached = ensureCache(wheel)
    if not cached then return end
    local car = Functions.getPlayerCar()
    if not car then return end
    local seat = car:FindFirstChild("DriverSeat")
    if not seat then return end
    local targetWorld = CFrame.new(worldPosition)
    cached.weld.C1 = targetWorld:Inverse() * seat.CFrame * cached.weld.C0
end

local steeringInverted, steeringInvertedCar = false, nil
Functions.invertSteering = function()
    if not Functions.isDriving() then return end
    local car = Functions.getPlayerCar()
    if steeringInvertedCar ~= car then
        steeringInverted = false
        steeringInvertedCar = car
    end
    local ctrl = Functions.getController()
    if not ctrl or not ctrl.Controls then return end
    local controls = ctrl.Controls
    if steeringInverted then
        if controls._origSteerLeft then
            controls.SteerLeft = controls._origSteerLeft
            controls.SteerRight = controls._origSteerRight
        end
        if controls._origSteerLeft2 then
            controls.SteerLeft2 = controls._origSteerLeft2
            controls.SteerRight2 = controls._origSteerRight2
        end
        JHK:Notify("Car Mods", "Steering restored", 2, "small", "bell")
    else
        local origLeft = controls._origSteerLeft or controls.SteerLeft
        local origRight = controls._origSteerRight or controls.SteerRight
        controls._origSteerLeft = origLeft
        controls._origSteerRight = origRight
        controls.SteerLeft = origRight
        controls.SteerRight = origLeft
        if controls.SteerLeft2 and controls.SteerRight2 then
            local origLeft2 = controls._origSteerLeft2 or controls.SteerLeft2
            local origRight2 = controls._origSteerRight2 or controls.SteerRight2
            controls._origSteerLeft2 = origLeft2
            controls._origSteerRight2 = origRight2
            controls.SteerLeft2 = origRight2
            controls.SteerRight2 = origLeft2
        end
        JHK:Notify("Car Mods", "Steering inverted", 2, "small", "bell")
    end
    steeringInverted = not steeringInverted
end

local speed = 200
local multiplier = 2
local keys = { W = false, A = false, S = false, D = false, Q = false, E = false, LeftShift = false }
local moves = {
    W = Vector3.new(0,0,-1),
    A = Vector3.new(-1,0,0),
    S = Vector3.new(0,0,1),
    D = Vector3.new(1,0,0),
    Q = Vector3.new(0,-1,0),
    E = Vector3.new(0,1,0)
}
local angle = 0
local angleSpeed = 360
local savedSprings = {}
local controlledCFrame = nil
local bounceTime = 0
local invertConns = {}
local invertCar = nil
local carFlyEnabled = false
local HelicopterFly = true
local helicopterDistance = 10
local helicopterHeight = 10
local carBounceEnabled = false
local carBounceInverted = false
local carBounceHeight = 3
local carBounceSpeed = 0.5
local carBounceStart = 0
local deadDrive = false
local invertWheelSpeed = false

local function disableSprings(car)
    savedSprings = {}
    if not car or not car:FindFirstChild("Wheels") then return end
    for _, wheel in car.Wheels:GetChildren() do
        for _, sp in wheel:GetDescendants() do
            if sp:IsA("SpringConstraint") then
                savedSprings[sp] = sp.Enabled
                sp.Enabled = false
            end
        end
    end
end

local function restoreSprings()
    for sp, was in pairs(savedSprings) do
        pcall(function() sp.Enabled = was end)
    end
    savedSprings = {}
end

local function orbitWheels(dt)
    local car = Functions.getPlayerCar()
    if not car or not Functions.isPlayerInOwnCar() then return end
    local pp = car.PrimaryPart or car:FindFirstChildWhichIsA("BasePart")
    if not pp or not car:FindFirstChild("Wheels") then return end
    local r = helicopterDistance
    local amount = #car.Wheels:GetChildren()
    for i, wheel in car.Wheels:GetChildren() do
        local a = math.rad(angle + (360 * i / amount))
        local lx = math.cos(a) * r
        local lz = math.sin(a) * r
        pcall(function()
            wheel.CFrame = pp.CFrame * CFrame.new(lx, helicopterHeight, lz)
        end)
    end
    angle = angle + angleSpeed * dt
end

local function controlledFly(dt)
    local car = Functions.getPlayerCar()
    if not car then return end
    local char = Functions.getChar()
    local isInOwnCar = Functions.isPlayerInOwnCar()
    if char and char:FindFirstChild("Humanoid") and char.Humanoid.Sit and not isInOwnCar then return end
    if not isInOwnCar then
        controlledCFrame = nil
        return
    end
    workspace.CurrentCamera.CameraSubject = lp.Character
    Functions.togglePlayerCar(false)
    if not controlledCFrame then
        controlledCFrame = car:GetPivot()
    end
    local pos = controlledCFrame.Position
    local newPos
    local lean = CFrame.identity
    local moveFrame
    if HelicopterFly then
        local _, camY = workspace.CurrentCamera.CFrame:ToOrientation()
        newPos = CFrame.new(pos) * CFrame.Angles(0, camY, 0)
        moveFrame = workspace.CurrentCamera.CFrame.Rotation
        if keys.W then lean = lean * CFrame.Angles(math.rad(-15), 0, 0) end
        if keys.S then lean = lean * CFrame.Angles(math.rad(15), 0, 0) end
        if keys.A then lean = lean * CFrame.Angles(0, 0, math.rad(15)) end
        if keys.D then lean = lean * CFrame.Angles(0, 0, math.rad(-15)) end
    else
        newPos = CFrame.new(pos) * workspace.CurrentCamera.CFrame.Rotation
        moveFrame = newPos
    end
    local planarMove = Vector3.zero
    local vertMove = 0
    for key, value in pairs(keys) do
        if value and moves[key] then
            if key == "Q" or key == "E" then
                vertMove = vertMove + moves[key].Y
            else
                planarMove = planarMove + moves[key]
            end
        end
    end
    local currentSpeed = keys.LeftShift and (speed * multiplier) or speed
    local world = Vector3.zero
    if planarMove.Magnitude > 0 then
        world = world + moveFrame:VectorToWorldSpace(planarMove.Unit)
    end
    world = world + Vector3.new(0, vertMove, 0)
    if world.Magnitude > 0 then
        newPos = newPos + world.Unit * currentSpeed * dt
    end
    controlledCFrame = newPos
    local primary = car.PrimaryPart
    if primary then
        primary.AssemblyLinearVelocity = Vector3.zero
        primary.AssemblyAngularVelocity = Vector3.zero
    end
    if HelicopterFly then
        car:PivotTo(newPos * lean)
        orbitWheels(dt)
    else
        car:PivotTo(newPos)
    end
end

local function carBounce(dt)
    local car = Functions.getPlayerCar()
    if not car or not Functions.isPlayerInOwnCar() or not car:FindFirstChild("Wheels") then return end
    bounceTime = bounceTime + dt * carBounceSpeed
    local t = bounceTime % 1
    local offset = (t < 0.5 and t * 2 or (1 - t) * 2) * carBounceHeight
    for _, wheel in car.Wheels:GetChildren() do
        if carBounceInverted then
            Functions.applyAxleOffset(wheel, { Y = offset - carBounceStart })
        else
            Functions.applyAxleOffset(wheel, { Y = -offset - carBounceStart })
        end
    end
end

local function cleanupInvertConns()
    for _, data in pairs(invertConns) do
        if data.conn then data.conn:Disconnect() end
    end
    invertConns = {}
    invertCar = nil
end

local function setupInvertForCar()
    cleanupInvertConns()
    local car = Functions.getPlayerCar()
    if not car or not car:FindFirstChild("Wheels") then return end
    invertCar = car
    for _, wheel in car.Wheels:GetChildren() do
        if wheel:IsA("BasePart") then
            local av = wheel:FindFirstChild("#AV")
            if av then
                local data = { ignoring = false }
                data.conn = av:GetPropertyChangedSignal("AngularVelocity"):Connect(function()
                    if not invertWheelSpeed or data.ignoring then return end
                    data.ignoring = true
                    av.AngularVelocity = -av.AngularVelocity
                    data.ignoring = false
                end)
                table.insert(invertConns, data)
            end
        end
    end
end

local Section = JHK:AddSection("Car Mods", "left")

Section:AddLabel("Car Fly"):AddToggle({
    Default = false,
    Flag = "carFlyEnabled",
    Callback = function(state)
        if not state then
            restoreSprings()
            if Functions.isDriving() then
                Functions.togglePlayerCar(true)
            end
        else
            local car = Functions.getPlayerCar()
            if car then disableSprings(car) end
        end
        controlledCFrame = nil
        carFlyEnabled = state
    end
}):AddKeybind({
    Default = "F",
    Text = "Fly Keybind",
    SyncToggle = true,
    Mode = "Toggle",
    Flag = "carFlyKeybind"
})

Section:AddSlider({
    Text = "Fly Speed",
    Default = 200,
    Min = 50,
    Max = 1000,
    Rounding = 0,
    Flag = "carFlySpeed",
    Callback = function(v) speed = v end
})

Section:AddSlider({
    Text = "Fly Boost Multiplier (Shift)",
    Default = 2,
    Min = 1,
    Max = 10,
    Rounding = 1,
    Flag = "carFlyBoost",
    Callback = function(v) multiplier = v end
})

Section:AddToggle({
    Default = true,
    Flag = "helicopterMode",
    Callback = function(state) HelicopterFly = state end
})

Section:AddSlider({
    Text = "Helicopter Distance",
    Default = 10,
    Min = 1,
    Max = 50,
    Rounding = 0,
    Flag = "helicopterDistance",
    Callback = function(v) helicopterDistance = v end
})

Section:AddSlider({
    Text = "Helicopter Height",
    Default = 10,
    Min = -20,
    Max = 20,
    Rounding = 0,
    Flag = "helicopterHeight",
    Callback = function(v) helicopterHeight = v end
})

Section:AddLabel("Bounce")

Section:AddToggle({
    Default = false,
    Flag = "carBounceEnabled",
    Callback = function(state) carBounceEnabled = state end
})

Section:AddToggle({
    Default = false,
    Flag = "carBounceInverted",
    Callback = function(state) carBounceInverted = state end
})

Section:AddSlider({
    Text = "Bounce Height",
    Default = 3,
    Min = 0,
    Max = 30,
    Rounding = 1,
    Flag = "carBounceHeight",
    Callback = function(v) carBounceHeight = v end
})

Section:AddSlider({
    Text = "Bounce Speed",
    Default = 0.5,
    Min = 0,
    Max = 20,
    Rounding = 1,
    Flag = "carBounceSpeed",
    Callback = function(v) carBounceSpeed = v end
})

Section:AddSlider({
    Text = "Bounce Start Height",
    Default = 0,
    Min = -30,
    Max = 30,
    Rounding = 1,
    Flag = "carBounceStart",
    Callback = function(v) carBounceStart = v end
})

Section:AddLabel("Wheel Mods")

Section:AddSlider({
    Text = "Camber",
    Default = 0,
    Min = -90,
    Max = 90,
    Rounding = 0,
    Flag = "camber",
    Callback = function(value)
        local car = Functions.getPlayerCar()
        if not car or not car:FindFirstChild("Wheels") then return end
        for _, wheel in car.Wheels:GetChildren() do
            Functions.applyCamber(wheel, value)
        end
    end
})

Section:AddSlider({
    Text = "Ride Height",
    Default = 0,
    Min = -30,
    Max = 30,
    Rounding = 1,
    Flag = "rideHeight",
    Callback = function(value)
        local car = Functions.getPlayerCar()
        if not car or not car:FindFirstChild("Wheels") then return end
        for _, wheel in car.Wheels:GetChildren() do
            Functions.applyAxleOffset(wheel, {Y = -value})
        end
    end
})

Section:AddSlider({
    Text = "Wheel Width",
    Default = 0,
    Min = -20,
    Max = 20,
    Rounding = 1,
    Flag = "wheelWidth",
    Callback = function(value)
        local car = Functions.getPlayerCar()
        if not car or not car:FindFirstChild("Wheels") then return end
        for _, wheel in car.Wheels:GetChildren() do
            Functions.applyAxleOffset(wheel, {X = value})
        end
    end
})

for _, side in ipairs({"FL", "FR", "RL", "RR"}) do
    Section:AddSlider({
        Text = "Ride Height " .. side,
        Default = 0,
        Min = -30,
        Max = 30,
        Rounding = 1,
        Flag = "rideHeight" .. side,
        Callback = function(value)
            local car = Functions.getPlayerCar()
            if not car or not car:FindFirstChild("Wheels") then return end
            local wheel = car.Wheels:FindFirstChild(side)
            if wheel then
                Functions.applyAxleOffset(wheel, {Y = -value})
            end
        end
    })
end

Section:AddLabel("Utility")

Section:AddToggle({
    Default = false,
    Flag = "deadDrive",
    Callback = function(state) deadDrive = state end
})

Section:AddButton({
    Name = "Fix Car (Mod Shop)",
    Icon = "gear",
    Callback = function()
        if not Functions.isDriving() or not Functions.isPlayerInOwnCar() then
            JHK:Notify("Car Mods", "Must be driving your own car", 3, "small", "bell")
            return
        end
        if lp:FindFirstChild("Is_Wanted") then
            JHK:Notify("Car Mods", "You are wanted!", 3, "small", "bell")
            return
        end
        local car = Functions.getPlayerCar()
        if not car then return end
        local old = car:GetPivot()
        car:PivotTo(CFrame.new(-673, 25, 157))
        task.spawn(function()
            local start = tick()
            repeat task.wait() until getrenv()._G.InModShop == true or tick() - start > 5
            pcall(function()
                replicatedStorage.FE:WaitForChild("ModShop"):InvokeServer(car.Name, "RepairVehicle")
            end)
            task.wait(0.5)
            pcall(function()
                replicatedStorage.FE:WaitForChild("ExitModShop"):FireServer(nil, { Accessories = {}, Texture = "Standard" })
            end)
            task.wait(0.3)
            car = Functions.getPlayerCar()
            if car then car:PivotTo(old) end
        end)
    end
})

Section:AddLabel("Trolling / Fun")

Section:AddToggle({
    Default = false,
    Flag = "invertWheelSpeed",
    Callback = function(state)
        invertWheelSpeed = state
        if state then
            setupInvertForCar()
            workspace.CurrentCamera.CameraSubject = Functions.getChar()
        else
            cleanupInvertConns()
        end
    end
})

Section:AddButton({
    Name = "Drive Upside Down",
    Icon = "two-carets-bar-vertical-flip",
    Callback = function()
        if not Functions.isDriving() then return end
        local car = Functions.getPlayerCar()
        if not car then return end
        local pos = car:GetPivot() * CFrame.new(0, 22, 0) * CFrame.Angles(0, math.pi, math.pi)
        Functions.makeWeightlessCar(true)
        if car:FindFirstChild("Wheels") then
            for _, wheel in car.Wheels:GetChildren() do
                wheel.CanCollide = false
            end
        end
        car:PivotTo(pos)
        if car:FindFirstChild("Wheels") then
            for _, wheel in car.Wheels:GetChildren() do
                Functions.applyAxleOffset(wheel, {Y = 15})
            end
        end
        for _ = 1, 120 do
            car:PivotTo(pos)
            task.wait()
        end
        if car:FindFirstChild("Wheels") then
            for _, wheel in car.Wheels:GetChildren() do
                wheel.CanCollide = true
            end
        end
        workspace.CurrentCamera.CameraSubject = Functions.getChar()
        pcall(function()
            replicatedStorage:WaitForChild("FE"):WaitForChild("ChangeClientSetting"):InvokeServer("AutoCarFlipSetting", false)
        end)
        Functions.invertSteering()
        invertWheelSpeed = true
        setupInvertForCar()
    end
})

Section:AddButton({
    Name = "Swap Front/Rear Wheels",
    Icon = "arrow-rotate-right",
    Callback = function()
        if not Functions.isPlayerInOwnCar() then return end
        local car = Functions.getPlayerCar()
        if not car or not car:FindFirstChild("Wheels") then return end
        local pos = car:GetPivot()
        if car.Wheels:FindFirstChild("FL") and car.Wheels:FindFirstChild("RL") then
            local a = (car.Wheels.FL.Position - car.Wheels.RL.Position).Magnitude
            Functions.applyAxleOffset(car.Wheels.FL, {Z = a})
            Functions.applyAxleOffset(car.Wheels.RL, {Z = -a})
        end
        if car.Wheels:FindFirstChild("FR") and car.Wheels:FindFirstChild("RR") then
            local a = (car.Wheels.FR.Position - car.Wheels.RR.Position).Magnitude
            Functions.applyAxleOffset(car.Wheels.FR, {Z = a})
            Functions.applyAxleOffset(car.Wheels.RR, {Z = -a})
        end
        car:PivotTo(pos)
    end
})

Section:AddButton({
    Name = "Make Threewheeler",
    Icon = "two-carets-bar-horizontal-flip",
    Callback = function()
        if not Functions.isDriving() then return end
        local car = Functions.getPlayerCar()
        if not car or not car:FindFirstChild("Wheels") then return end
        if car.Wheels:FindFirstChild("FL") and car.Wheels:FindFirstChild("FR") then
            local a = (car.Wheels.FL.Position - car.Wheels.FR.Position).Magnitude
            Functions.applyAxleOffset(car.Wheels.FL, {X = -(a/2)})
            Functions.applyAxleOffset(car.Wheels.FR, {X = -(a/2)})
        end
    end
})

Section:AddButton({
    Name = "Toggle Weightless",
    Icon = "arrow-large-up",
    Callback = function()
        if not Functions.isDriving() then return end
        local car = Functions.getPlayerCar()
        if not car then return end
        local currently = (weightsCar == car)
        Functions.makeWeightlessCar(not currently)
        JHK:Notify("Car Mods", currently and "Weight restored" or "Car is now weightless", 2, "small", "bell")
    end
})

Section:AddButton({
    Name = "Invert Steering",
    Icon = "arrow-rotate-right",
    Callback = function()
        Functions.invertSteering()
    end
})

Section:AddButton({
    Name = "Flip Car",
    Icon = "two-carets-bar-vertical-flip",
    Callback = function()
        if not Functions.isDriving() then return end
        local car = Functions.getPlayerCar()
        if not car then return end
        local pivot = car:GetPivot()
        local newPos = pivot.Position + Vector3.new(0, 5, 0)
        car:PivotTo(CFrame.new(newPos) * (pivot - pivot.Position) * CFrame.Angles(0, 0, math.pi))
    end
})

userInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    local key = input.KeyCode.Name
    if keys[key] ~= nil then keys[key] = true end
end)

userInputService.InputEnded:Connect(function(input)
    local key = input.KeyCode.Name
    if keys[key] ~= nil then keys[key] = false end
end)

local lastDriving = 0
local debounce = false

runService.Heartbeat:Connect(function()
    local char = Functions.getChar()
    local car = Functions.getPlayerCar()
    if not car or not char or not char:FindFirstChild("Humanoid") then return end
    if deadDrive and not debounce and (os.time() - lastDriving) < 2 and char.Humanoid.Health <= 0.2 and not Functions.isPlayerInOwnCar() then
        debounce = true
        repeat task.wait() until char.Humanoid.SeatPart == nil
        task.wait(0.5)
        if car:FindFirstChild("DriverSeat") then
            car.DriverSeat:Sit(char.Humanoid)
        end
        for _, part in char:GetChildren() do
            if part:IsA("BasePart") and string.find(part.Name, "Leg") then
                part.CanCollide = false
            end
        end
    end
    if deadDrive and car:FindFirstChild("Control_Values") and car.Control_Values:FindFirstChild("Health") then
        if car.Control_Values.Health.Value <= 0 then
            car.Control_Values.Health.Value = 69
        end
    end
    if Functions.isDriving() then
        lastDriving = os.time()
        debounce = false
    end
    if deadDrive then
        pcall(function()
            if lighting:FindFirstChild("HealthBlur") then lighting.HealthBlur.Enabled = false end
            if lighting:FindFirstChild("HealthColor") then lighting.HealthColor.Enabled = false end
            if lp.PlayerGui:FindFirstChild("GameGui") and lp.PlayerGui.GameGui:FindFirstChild("HealthDamage") then
                lp.PlayerGui.GameGui.HealthDamage.Visible = false
            end
        end)
    end
end)

runService.Heartbeat:Connect(function()
    if not invertWheelSpeed then return end
    local car = Functions.getPlayerCar()
    if car ~= invertCar then
        if car and Functions.isDriving() then
            setupInvertForCar()
        else
            cleanupInvertConns()
        end
    end
end)

runService.Heartbeat:Connect(function(dt)
    if carFlyEnabled then
        controlledFly(dt)
    end
    if carBounceEnabled then
        carBounce(dt)
    end
end)

JHK:Notify("Car Mods", "Car Mods addon loaded", 4, "small", "paper-airplane")
