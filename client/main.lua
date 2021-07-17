QBCore = nil
local closestDoor, closestV, closestDistance, playerPed, playerCoords, doorCount, retrievedData
local playerNotActive = true

Citizen.CreateThread(function()
	while QBCore == nil do
		TriggerEvent('QBCore:GetObject', function(obj) QBCore = obj end)
		Citizen.Wait(0)
	end
	-- Sync doors with the server
	Citizen.Wait(1000)
	QBCore.Functions.TriggerCallback('nui_doorlock:getDoorInfo', function(doorInfo)
		for doorID, locked in pairs(doorInfo) do
			Config.DoorList[doorID].locked = locked
		end
		retrievedData = true
	end)
	while not retrievedData do Citizen.Wait(0) end
	while IsPedStill(PlayerPedId()) and not IsPedInAnyVehicle(PlayerPedId()) do Citizen.Wait(0) end
	updateDoors()
	playerNotActive = nil
	retrievedData = nil
	PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded')
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
	PlayerData = QBCore.Functions.GetPlayerData()
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate')
AddEventHandler('QBCore:Client:OnJobUpdate', function(job)
	PlayerData.job = job
end)

-- Sync a door with the server
RegisterNetEvent('nui_doorlock:setState')
AddEventHandler('nui_doorlock:setState', function(sid, doorID, locked, isScript, src)
    local serverid = GetPlayerServerId(PlayerId())
    if sid == serverid and not isScript then dooranim() end
    if Config.DoorList[doorID] then
        Config.DoorList[doorID].locked = locked
        updateDoors(doorID)
        while true do
            Citizen.Wait(5)
            if Config.DoorList[doorID].doors then
                for k, v in pairs(Config.DoorList[doorID].doors) do
                    if not IsDoorRegisteredWithSystem(v.doorHash) then return end -- If door is not registered end the loop
                    v.currentHeading = GetEntityHeading(v.object)
                    v.doorState = DoorSystemGetDoorState(v.doorHash)
                    if Config.DoorList[doorID].slides then
                        if Config.DoorList[doorID].locked then
                            DoorSystemSetDoorState(v.doorHash, 1, false, false) -- Set to locked
                            DoorSystemSetAutomaticDistance(v.doorHash, 0.0, false, false)
                            if k == 2 then playSound(Config.DoorList[doorID], isScript, src) return end -- End the loop
                        else
                            DoorSystemSetDoorState(v.doorHash, 0, false, false) -- Set to unlocked
                            DoorSystemSetAutomaticDistance(v.doorHash, 30.0, false, false)
                            if k == 2 then playSound(Config.DoorList[doorID], isScript, src) return end -- End the loop
                        end
                    elseif Config.DoorList[doorID].locked and (v.doorState == 4) then
                        if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(v.object, true) end
                        DoorSystemSetDoorState(v.doorHash, 1, false, false) -- Set to locked
                        if Config.DoorList[doorID].doors[1].doorState == Config.DoorList[doorID].doors[2].doorState then playSound(Config.DoorList[doorID], isScript, src) return end -- End the loop
                    elseif not Config.DoorList[doorID].locked then
                        if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(v.object, false) end
                        DoorSystemSetDoorState(v.doorHash, 0, false, false) -- Set to unlocked
                        if Config.DoorList[doorID].doors[1].doorState == Config.DoorList[doorID].doors[2].doorState then playSound(Config.DoorList[doorID], isScript, src) return end -- End the loop
                    else
                        if round(v.currentHeading, 0) == round(v.objHeading, 0) then
                            DoorSystemSetDoorState(v.doorHash, 4, false, false) -- Force to close
                        end
                    end
                end
            else
                if not IsDoorRegisteredWithSystem(Config.DoorList[doorID].doorHash) then return end -- If door is not registered end the loop
                Config.DoorList[doorID].currentHeading = GetEntityHeading(Config.DoorList[doorID].object)
                Config.DoorList[doorID].doorState = DoorSystemGetDoorState(Config.DoorList[doorID].doorHash)
                if Config.DoorList[doorID].slides then
                    if Config.DoorList[doorID].locked then
                        DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 1, false, false) -- Set to locked
                        DoorSystemSetAutomaticDistance(Config.DoorList[doorID].doorHash, 0.0, false, false)
                        playSound(Config.DoorList[doorID], isScript, src)
                        return -- End the loop
                    else
                        DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 0, false, false) -- Set to unlocked
                        DoorSystemSetAutomaticDistance(Config.DoorList[doorID].doorHash, 30.0, false, false)
                        playSound(Config.DoorList[doorID], isScript, src)
                        return -- End the loop
                    end
                elseif Config.DoorList[doorID].locked and (Config.DoorList[doorID].doorState == 4) then
                    if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(Config.DoorList[doorID].object, true) end
                    DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 1, false, false) -- Set to locked
                    playSound(Config.DoorList[doorID], isScript, src)
                    return -- End the loop
                elseif not Config.DoorList[doorID].locked then
                    if Config.DoorList[doorID].oldMethod then FreezeEntityPosition(Config.DoorList[doorID].object, false) end
                    DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 0, false, false) -- Set to unlocked
                    playSound(Config.DoorList[doorID], isScript, src)
                    return -- End the loop
                else
                    if round(Config.DoorList [doorID].currentHeading, 0) == round(Config.DoorList[doorID].objHeading, 0) then
                        DoorSystemSetDoorState(Config.DoorList[doorID].doorHash, 4, false, false) -- Force to close
                    end
                end
            end
        end
    end
end)

function playSound(door, isScript, src)
	local origin
	if isScript then return end
	if src and src ~= playerPed then src = NetworkGetEntityFromNetworkId(src) end
	if not src then origin = door.textCoords elseif src == playerPed then origin = playerCoords else origin = NetworkGetPlayerCoords(src) end
	local distance = #(playerCoords - origin)
	if distance < 10 then
		if not door.audioLock then
			if door.audioRemote then
				door.audioLock = {['file'] = 'button-remote.ogg', ['volume'] = 0.08}
				door.audioUnlock = {['file'] = 'button-remote.ogg', ['volume'] = 0.08}
			else
				door.audioLock = {['file'] = 'door-bolt-4.ogg', ['volume'] = 0.1}
				door.audioUnlock = {['file'] = 'door-bolt-4.ogg', ['volume'] = 0.1}
			end
		end
		local sfx_level = GetProfileSetting(300)
		if door.locked then SendNUIMessage ({type = 'audio', audio = door.audioLock, distance = distance, sfx = sfx_level})
		else SendNUIMessage ({type = 'audio', audio = door.audioUnlock, distance = distance, sfx = sfx_level}) end
	end
end

local isDrawing = false

function Draw3dNUI(text)
    local paused = false
    if IsPauseMenuActive() then paused = true end
    isDrawing = true
    if paused then SendNUIMessage ({type = "hide"}) else SendNUIMessage({type = "display", text = text}) end
    Citizen.Wait(0)
end

function loadAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do
        RequestAnimDict(dict)
        Citizen.Wait(5)
    end
end

function dooranim()
	Citizen.CreateThread(function()
    		loadAnimDict("anim@heists@keycard@") 
		TaskPlayAnim(playerPed, "anim@heists@keycard@", "exit", 8.0, 1.0, -1, 16, 0, 0, 0, 0)
    		Citizen.Wait(550)
		ClearPedTasks(playerPed)
	end)
end

function round(num, decimal)
	local mult = 10^(decimal)
	return math.floor(num * mult + 0.5) / mult
end

function debug(doorID, data)
	if #(playerCoords - data.textCoords) < 3 then
		for k,v in pairs(data) do
			print(  ('%s = %s'):format(k, v) )
		end
		if data.doors then
			for k, v in pairs(data.doors) do
				print('\nCurrent Heading '..k..': '..GetEntityHeading(v.object))
				print('Current Coords '..k..': '..GetEntityCoords(v.object))
			end
		else
			print('\nCurrent Heading: '..GetEntityHeading(data.object))
			print('Current Coords: '..GetEntityCoords(data.object))
		end
	end
end

function setTextCoords(data)
	local minDimension, maxDimension = GetModelDimensions(data.objHash)
	local dimensions = maxDimension - minDimension
	local dx, dy = tonumber(dimensions.x), tonumber(dimensions.y)
	if dy <= -1 or dy >= 1 then dx = dy end
	if data.fixText then
		return GetOffsetFromEntityInWorldCoords(data.object, dx/2, 0, 0)
	else
		return GetOffsetFromEntityInWorldCoords(data.object, -dx/2, 0, 0)
	end
end

function updateDoors(specificDoor)
	playerCoords = GetEntityCoords(PlayerPedId())
	for doorID, data in pairs(Config.DoorList) do
		if (not specificDoor or doorID == specificDoor) then
			if data.doors then
				for k,v in pairs(data.doors) do
					if #(playerCoords - v.objCoords) < 30 then
						Citizen.Wait(1)
						v.object = GetClosestObjectOfType(v.objCoords, 1.0, v.objHash, false, false, false)
						if data.delete then
							SetEntityAsMissionEntity(v.object, 1, 1)
							DeleteObject(v.object)
							v.object = nil
						end
						if v.object then
							v.doorHash = 'doorlock_'..doorID..'_'..k
							if not IsDoorRegisteredWithSystem(v.doorHash) then
								AddDoorToSystem(v.doorHash, v.objHash, v.objCoords, false, false, false)
								if data.locked then
									DoorSystemSetDoorState(v.doorHash, 4, false, false) DoorSystemSetDoorState(v.doorHash, 1, false, false)
								else
									DoorSystemSetDoorState(v.doorHash, 0, false, false) if data.oldMethod then FreezeEntityPosition(v.object, false) end
								end
							end
						end
					elseif v.object then RemoveDoorFromSystem(v.doorHash) end
				end
			elseif not data.doors then
				if #(playerCoords - data.objCoords) < 30 then
					Citizen.Wait(2)
					if data.slides then data.object = GetClosestObjectOfType(data.objCoords, 5.0, data.objHash, false, false, false) else
						data.object = GetClosestObjectOfType(data.objCoords, 1.0, data.objHash, false, false, false)
					end
					if data.delete then
						SetEntityAsMissionEntity(data.object, 1, 1)
						DeleteObject(data.object)
						data.object = nil
					end
					if data.object then
						data.doorHash = 'doorlock_'..doorID
						if not IsDoorRegisteredWithSystem(data.doorHash) then
							AddDoorToSystem(data.doorHash, data.objHash, data.objCoords, false, false, false) 
							if data.locked then
								DoorSystemSetDoorState(data.doorHash, 4, false, false) DoorSystemSetDoorState(data.doorHash, 1, false, false)
							else
								DoorSystemSetDoorState(data.doorHash, 0, false, false) if data.oldMethod then FreezeEntityPosition(data.object, false) end
							end
						end
					end
				elseif data.object then RemoveDoorFromSystem(data.doorHash) end
			end
			-- set text coords
			if not data.setText and data.doors then
				for k,v in pairs(data.doors) do
					if k == 1 and DoesEntityExist(v.object) then
						data.textCoords = v.objCoords
					elseif k == 2 and DoesEntityExist(v.object) and data.textCoords then
						local textDistance = data.textCoords - v.objCoords
						data.textCoords = (data.textCoords - (textDistance / 2))
						data.setText = true
					end
					if k == 2 and data.textCoords and data.slides then
						if GetEntityHeightAboveGround(v.object) < 1 then
							data.textCoords = vector3(data.textCoords.x, data.textCoords.y, data.textCoords.z+1.2)
						end
					end
				end
			elseif not data.setText and not data.doors and DoesEntityExist(data.object) then
				if data.garage == true then
					data.textCoords = data.objCoords
					data.setText = true
				else
					data.textCoords = setTextCoords(data)
					data.setText = true
				end
				if data.slides then
					if GetEntityHeightAboveGround(data.object) < 1 then
						data.textCoords = vector3(data.textCoords.x, data.textCoords.y, data.textCoords.z+1.6)
					end
				end
			end
		end
	end
	doorCount = DoorSystemGetSize()
	lastCoords = playerCoords
end

Citizen.CreateThread(function()
	while playerNotActive do Citizen.Wait(100) end
	lastCoords = playerCoords
	while playerCoords do
		local distance = #(playerCoords - lastCoords)
		if distance > 30 then
			updateDoors()
			lastCoords = playerCoords
		end
		Citizen.Wait(500)
		if doorCount == 0 then Citizen.Wait(500) end
	end
end)

local doorSleep = 500
Citizen.CreateThread(function()
	while not playerCoords do Citizen.Wait(0) end
	updateDoors()
	while true do
		if doorCount then
			while true do
				if not closestDistance then break end
				Citizen.Wait(10)
			end
			local distance
                        doorSleep = 100
			for k,v in pairs(Config.DoorList) do
				if v.setText and v.textCoords then
					distance = #(v.textCoords - playerCoords)
					if distance < 10 and distance < v.maxDistance then
						closestDoor, closestV, closestDistance = k, v, distance
                                                doorSleep = 0
	     				end
				end
			end
			Citizen.Wait(doorSleep)
		else Citizen.Wait(1000); doorSleep = 500; end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		playerPed = PlayerPedId()
		playerCoords = GetEntityCoords(playerPed)
		if doorCount ~= nil and doorCount ~= 0 and closestDistance and closestV.setText then
			closestDistance = #(closestV.textCoords - playerCoords)
			if closestDistance < closestV.maxDistance then
				if not closestV.doors then
					local doorState = DoorSystemGetDoorState(closestV.doorHash)
					if closestV.locked and doorState ~= 1 then
						Draw3dNUI('Locking')
					elseif not closestV.locked and not CheckAuth(closestV) then
						if Config.ShowUnlockedText then Draw3dNUI('Unlocked') else if isDrawing then SendNUIMessage ({type = "hide"}) isDrawing = false end end
					elseif not closestV.locked and CheckAuth(closestV) then
						if Config.ShowUnlockedText then Draw3dNUI('[E] - Unlocked') else if isDrawing then SendNUIMessage ({type = "hide"}) isDrawing = false end end
					elseif closestV.locked and not CheckAuth(closestV) then
						Draw3dNUI('Locked')
					elseif closestV.locked and CheckAuth(closestV) then
						Draw3dNUI('[E] - Locked')
					end
				else
					local door = {}
					local state = {}
					door[1] = closestV.doors[1]
					door[2] = closestV.doors[2]
					state[1] = DoorSystemGetDoorState(door[1].doorHash)
					state[2] = DoorSystemGetDoorState(door[2].doorHash)
					
					if closestV.locked and (state[1] ~= 1 or state[2] ~= 1) then
						Draw3dNUI('Locking')
					elseif not closestV.locked and not CheckAuth(closestV) then
						if Config.ShowUnlockedText then Draw3dNUI('Unlocked') else if isDrawing then SendNUIMessage ({type = "hide"}) isDrawing = false end end
					elseif not closestV.locked and CheckAuth(closestV) then
						if Config.ShowUnlockedText then Draw3dNUI('[E] - Unlocked') else if isDrawing then SendNUIMessage ({type = "hide"}) isDrawing = false end end
					elseif closestV.locked and not CheckAuth(closestV) then
						Draw3dNUI('Locked')
					elseif closestV.locked and CheckAuth(closestV) then
						Draw3dNUI('[E] - Locked')
					end
				end
			else
				if closestDistance > closestV.maxDistance and isDrawing then
					SendNUIMessage ({type = "hide"}) isDrawing = false
				end
				closestDoor, closestV, closestDistance = nil, nil, nil
			end
		end
		
		if doorCount == 0 then doorSleep = 1000 Citizen.Wait(doorSleep) end
	end
end)

function CheckAuth(doorID)
	local canOpen = false
	local gottenresult = false

	if doorID.authorizedJobs then
		for job,rank in pairs(doorID.authorizedJobs) do
			if (job == PlayerData.job.name) then
				canOpen = true
				gottenresult = true
				break
			end
		end
	end

	if doorID.items and not canOpen then
		QBCore.Functions.TriggerCallback('nui_doorlock:CheckItems', function(result)
			if result then
				canOpen = true
				gottenresult = true
			else
				canOpen = false
				gottenresult = true
			end
		end, doorID.items, doorID.locked)
	end

	if not doorID.authorizedJobs and not doorID.items and not canOpen then
		canOpen = true
		gottenresult = true
	end

	while not gottenresult do
		Wait(1)
	end

    return canOpen
end

exports('updateDoors', updateDoors)
-- Use this export if doors do not load after a teleport event (such as /tp, /setcoords, /jail, etc)
-- `exports.nui_doorlock:updateDoors()`

RegisterCommand('doorlock', function()
	if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] and closestDoor then
		if IsControlPressed(0, 86) or IsControlReleased(0, 86) then key = 'e' end
		local veh = GetVehiclePedIsIn(playerPed)
		if veh and key == 'e' then
			Citizen.CreateThread(function()
				local counter = 0
				local siren = IsVehicleSirenOn(veh)
				repeat
					DisableControlAction(0, 86, true)
					SetHornEnabled(veh, false)
					if not siren then SetVehicleSiren(veh, false) end
					counter = counter + 1
					Citizen.Wait(0)
				until (counter == 100)
				SetHornEnabled(veh, true)
			end)
		end
		local locked = not closestV.locked
		if closestV.audioRemote then src = NetworkGetNetworkIdFromEntity(playerPed) else src = nil end
		TriggerServerEvent('nui_doorlock:server:updateState', closestDoor, locked, src, false, false) -- Broadcast new state of the door to everyone
	end
end)
TriggerEvent("chat:removeSuggestion", "/doorlock")
RegisterKeyMapping('doorlock', Config.KeybingText, 'keyboard', 'e')

RegisterNetEvent('lockpicks:UseLockpick')
AddEventHandler('lockpicks:UseLockpick', function(isAdvanced)
	if not PlayerData.metadata["isdead"] and not PlayerData.metadata["ishandcuffed"] and closestDoor and closestV.lockpick and closestV.locked then
		if isAdvanced then
			TriggerEvent('qb-lockpick:client:openLockpick', advlockpickFinish)
		else
			TriggerEvent('qb-lockpick:client:openLockpick', lockpickFinish)
		end
	end
end)

function lockpickFinish(success)
    if success then
		QBCore.Functions.Notify('Success!', 'success', 2500)
		TaskTurnPedToFaceCoord(playerPed, closestV.objCoords.x, closestV.objCoords.y, closestV.objCoords.z, 0)
		Citizen.Wait(300)
		local count = 0
		while GetIsTaskActive(playerPed, 225) do Citizen.Wait(10) count = count + 1 if count == 150 then break end end
		Citizen.Wait(1800)
		TriggerServerEvent('nui_doorlock:server:updateState', closestDoor, false, false, true, false) -- Broadcast new state of the door to everyone
    else
		if math.random(1, 100) <= 17 then
			TriggerServerEvent("QBCore:Server:RemoveItem", "lockpick", 1, false)
			TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["lockpick"], "remove")
		end
        QBCore.Functions.Notify('Failed..', 'error', 2500)
    end
end

function advlockpickFinish(success)
    if success then
		QBCore.Functions.Notify('Success!', 'success', 2500)
		TaskTurnPedToFaceCoord(playerPed, closestV.objCoords.x, closestV.objCoords.y, closestV.objCoords.z, 0)
		Citizen.Wait(300)
		local count = 0
		while GetIsTaskActive(playerPed, 225) do Citizen.Wait(10) count = count + 1 if count == 150 then break end end
		Citizen.Wait(1800)
		TriggerServerEvent('nui_doorlock:server:updateState', closestDoor, false, false, true, false) -- Broadcast new state of the door to everyone
    else
		if math.random(1, 100) <= 17 then
			TriggerServerEvent("QBCore:Server:RemoveItem", "advancedlockpick", 1, false)
			TriggerEvent('inventory:client:ItemBox', QBCore.Shared.Items["advancedlockpick"], "remove")
		end
        QBCore.Functions.Notify('Failed..', 'error', 2500)
    end
end

function closeNUI()
	SetNuiFocus(false, false)
	SendNUIMessage({type = "newDoorSetup", enable = false})
	receivedDoorData = nil
end

RegisterNUICallback('newDoor', function(data, cb)
	receivedDoorData = true
	arg = data
	closeNUI()
end)

RegisterNUICallback('close', function(data, cb)
	closeNUI()
end)

RegisterCommand('-nui', function(playerId, args, rawCommand)
	closeNUI()
end, false)

RegisterNetEvent('nui_doorlock:newDoorSetup')
AddEventHandler('nui_doorlock:newDoorSetup', function(args)
	if not args[1] then
		receivedDoorData = false
		SetNuiFocus(true, true)
		SendNUIMessage({type = "newDoorSetup", enable = true})
		while receivedDoorData == false do Citizen.Wait(5) DisableAllControlActions(0) end
	end
	--if not args[1] then print('/newdoor [doortype] [locked] [jobs]\nDoortypes: door, sliding, garage, double, doublesliding\nLocked: true or false\nJobs: Up to four can be added with the command') return end
	if arg then doorType = arg.doortype else doorType = args[1] end
	if arg then doorLocked = arg.doorlocked else doorLocked = not not args[2] end
	local validTypes = {['door']=true, ['sliding']=true, ['garage']=true, ['double']=true, ['doublesliding']=true}
	if not validTypes[doorType] then print(doorType.. ' is not a valid doortype') return end
	if arg and arg.item == '' and arg.job1 == '' then print('You must enter either a job or item for lock authorisation') return end
	if args[7] then print('You can only set four authorised jobs - if you want more, add them to the config later') return end
	if arg then configname = arg.configname else configname = '' end
	if doorType == 'door' or doorType == 'sliding' or doorType == 'garage' then
		local entity, coords, heading, model = nil, nil, nil, nil
		local result = false
		print('Aim at your desired door and press left mouse button')
		while true do
			Citizen.Wait(0)
			if IsPlayerFreeAiming(PlayerId()) then
				result, entity = GetEntityPlayerIsFreeAimingAt(PlayerId())
				coords = GetEntityCoords(entity)
				model = GetEntityModel(entity)
				heading = GetEntityHeading(entity)
			end
			if result then 
				DrawInfos("Coordinates: " .. coords .. "\nHeading: " .. heading .. "\nHash: " .. model)
			else 
				DrawInfos("Aim at your desired door and shoot") 
			end
			if IsControlJustPressed(0, 24) then 
				break 
			end
		end
		if not model or model == 0 then print('Did not receive a model hash\nIf the door is transparent, make sure you aim at the frame') return end
		local jobs = {}
		if args[3] then
			jobs[1] = args[3]
			jobs[2] = args[4]
			jobs[3] = args[5]
			jobs[4] = args[6]
		else
			if arg.job1 ~= '' then jobs[1] = arg.job1 end
			if arg.job2 ~= '' then jobs[2] = arg.job2 end
			if arg.job3 ~= '' then jobs[3] = arg.job3 end
			if arg.job4 ~= '' then jobs[4] = arg.job4 end
			if arg.item ~= '' then item = arg.item end
		end
		local maxDistance, slides, garage = 2.0, false, false
		if doorType == 'sliding' then slides = true
		elseif doorType == 'garage' then maxDistance, slides, garage = 6.0, true, true end
		if slides then maxDistance = 6.0 end
		local doorHash = 'doorlock_'..#Config.DoorList + 1
		AddDoorToSystem(doorHash, model, coords, false, false, false)
		DoorSystemSetDoorState(doorHash, 4, false, false)
		coords = GetEntityCoords(entity)
		heading = GetEntityHeading(entity)
		RemoveDoorFromSystem(doorHash)
		if arg then doorname = arg.doorname end
		TriggerServerEvent('nui_doorlock:newDoorCreate', configname, model, heading, coords, jobs, item, doorLocked, maxDistance, slides, garage, false, doorname)
		print('Successfully sent door data to the server')
	elseif doorType == 'double' or doorType == 'doublesliding' then
		local entity, coords, heading, model = {}, {}, {}, {}
		local result = false
		print('Aim at each desired door and press left mouse button')
		while true do
			Citizen.Wait(0)
			if IsPlayerFreeAiming(PlayerId()) then
				result, entity[1] = GetEntityPlayerIsFreeAimingAt(PlayerId())
				coords[1] = GetEntityCoords(entity[1])
				model[1] = GetEntityModel(entity[1])
				heading[1] = GetEntityHeading(entity[1])
			end
			if result then DrawInfos("Coordinates: " .. coords[1] .. "\nHeading: " .. heading[1] .. "\nHash: " .. model[1])
			else DrawInfos("Aim at your desired door and shoot") end
			if IsControlJustPressed(0, 24) then break end
		end
		result = false
		while true do
			Citizen.Wait(0)
			if IsPlayerFreeAiming(PlayerId()) then
				result, entity[2] = GetEntityPlayerIsFreeAimingAt(PlayerId())
				coords[2] = GetEntityCoords(entity[2])
				model[2] = GetEntityModel(entity[2])
				heading[2] = GetEntityHeading(entity[2])
			end
			if result then DrawInfos("Coordinates: " .. coords[2] .. "\nHeading: " .. heading[2] .. "\nHash: " .. model[2])
			else DrawInfos("Aim at your desired door and shoot") end
			if IsControlJustPressed(0, 24) then break end
		end
		if not model[1] or model[1] == 0 or not model[2] or model[2] == 0 then print('Did not receive a model hash\nIf the door is transparent, make sure you aim at the frame') return end
		if entity[1] == entity[2] then print('Can not add double door if entities are the same') return end
		local jobs = {}
		if args[3] then
			jobs[1] = args[3]
			jobs[2] = args[4]
			jobs[3] = args[5]
			jobs[4] = args[6]
		else
			if arg.job1 ~= '' then jobs[1] = arg.job1 end
			if arg.job2 ~= '' then jobs[2] = arg.job2 end
			if arg.job3 ~= '' then jobs[3] = arg.job3 end
			if arg.job4 ~= '' then jobs[4] = arg.job4 end
			if arg.item ~= '' then item = arg.item end
		end
		local maxDistance, slides, garage = 2.5, false, false
		if doorType == 'sliding' or doorType == 'doublesliding' then slides = true end
		if slides then maxDistance = 6.0 end

		local doors = #Config.DoorList + 1
		local doorHash = {}
		doorHash[1] = 'doorlock_'..doors..'_'..'1'
		doorHash[2] = 'doorlock_'..doors..'_'..'2'
		for i=1, #doorHash do
			AddDoorToSystem(doorHash[i], model[i], coords[i], false, false, false)
			DoorSystemSetDoorState(doorHash[i], 4, false, false)
			coords[i] = GetEntityCoords(entity[i])
			heading[i] = GetEntityHeading(entity[i])
			RemoveDoorFromSystem(doorHash[i])
		end
		if arg then doorname = arg.doorname end
		TriggerServerEvent('nui_doorlock:newDoorCreate', configname, model, heading, coords, jobs, item, doorLocked, maxDistance, slides, garage, true, doorname)
		print('Successfully sent door data to the server')
		arg = nil
	end
end)

function DrawInfos(text)
    SetTextColour(255, 255, 255, 255)   -- Color
    SetTextFont(4)                      -- Font
    SetTextScale(0.4, 0.4)              -- Scale
    SetTextWrap(0.0, 1.0)               -- Wrap the text
    SetTextCentre(false)                -- Align to center(?)
    SetTextDropshadow(0, 0, 0, 0, 255)  -- Shadow. Distance, R, G, B, Alpha.
    SetTextEdge(50, 0, 0, 0, 255)       -- Edge. Width, R, G, B, Alpha.
    SetTextOutline()                    -- Necessary to give it an outline.
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(0.015, 0.71)               -- Position
end

RegisterNetEvent('nui_doorlock:newDoorAdded')
AddEventHandler('nui_doorlock:newDoorAdded', function(newDoor, doorID, locked)
	Config.DoorList[doorID] = newDoor
	updateDoors()
	TriggerEvent('nui_doorlock:setState', GetPlayerServerId(PlayerId()), doorID, locked, false)
end)
