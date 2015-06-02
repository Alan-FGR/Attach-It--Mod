--	####################################################################
-- Known Issues: Radar won't detect some vehicles. Attached vehicles will
--		will have some resistance on their wheels.
-- CONFIGURE THE KEYS BELOW. Further down you find a list of the codes

local modekey = 106
local attachkey = 111

--	####################################################################
--		KEY CODES
--	####################################################################
--
--	Space = 32            D4 = 52       O = 79             NumPad4 = 100         F9 = 120
--  PageUp = 33           D5 = 53       P = 80             NumPad5 = 101         F10 = 121
--	Next = 34             D6 = 54       Q = 81             NumPad6 = 102         F11 = 122
--  End = 35              D7 = 55       R = 82             NumPad7 = 103         F12 = 123
--	Home = 36             D8 = 56       S = 83             NumPad8 = 104         F13 = 124
--  Left = 37             D9 = 57       T = 84             NumPad9 = 105         F14 = 125
--	Up = 38               A = 65        U = 85             Multiply = 106        F15 = 126
--  Right = 39            B = 66        V = 86             Add = 107             F16 = 127
--	Down = 40             C = 67        W = 87             Separator = 108       F17 = 128
--  Select = 41           D = 68        X = 88             Subtract = 109        F18 = 129
--  Print = 42            E = 69        Y = 89             Decimal = 110         F19 = 130
--	Execute = 43          F = 70        Z = 90             Divide = 111          F20 = 131
--  PrintScreen = 44      G = 71        LWin = 91          F1 = 112              F21 = 132
--	Insert = 45           H = 72        RWin = 92          F2 = 113              F22 = 133
--  Delete = 46           I = 73        Apps = 93          F3 = 114              F23 = 134
--	Help = 47             J = 74        Sleep = 95         F4 = 115              F24 = 135
--  D0 = 48               K = 75        NumPad0 = 96       F5 = 116            
--	D1 = 49               L = 76        NumPad1 = 97       F6 = 117            
--  D2 = 50               M = 77        NumPad2 = 98       F7 = 118            
--	D3 = 51               N = 78        NumPad3 = 99       F8 = 119            
--
--	####################################################################






local raylength = 10

local szaboattach = {}

function szaboattach.unload()
end
function szaboattach.init()
end

local lastrope = 0
local lastattachedv = 0

local modes = {
{0,0},
{2,0},
{5,0},
{-2,0},
{-5,0},
{0,2},
{0,5},
{0,-2},
{0,-5},
{0,-1}--#10 - special mode 1 (y and z) y=ground, z=air
}

local curmode = 1
local curdir = 1

local lastratiobutstate = false
local lastattachbutstate = false

local lasthitstate = false

local detachcooldown = 0

local function modecontrol()
	local ratiobutstate = get_key_pressed(modekey) or
	(CONTROLS.IS_CONTROL_PRESSED(2, 190) and CONTROLS.IS_CONTROL_JUST_PRESSED(2, 201))--mult or -> + A
	if(ratiobutstate and not lastratiobutstate) then
		curmode = curmode+1
		lastrope = 0
		lastattachedv = 0
		if(curmode > #modes) then
			curmode = 1
			curdir = curdir*-1
		end
	end
	lastratiobutstate = ratiobutstate
end

local attachbutstate = false
local function attachcontrol(currentVehicle)
	trigger = false
	attachbutstate = get_key_pressed(attachkey) or CONTROLS.IS_CONTROL_PRESSED(2, 201)--divide or A
	if(attachbutstate and not lastattachbutstate) then
		if (lastrope ~= 0 and currentVehicle == lastattachedv)then
			print('detaching rope')
			ROPE.DELETE_ROPE(lastrope)
			lastrope = 0
			lastattachedv = 0
			detachcooldown = 30
		else
			trigger = true
		end
	end
	lastattachbutstate = attachbutstate
	return trigger
end

local searchangle = 0
local function drawradarline(origin, center, radius, alpha)
	searchangle = searchangle + 0.005
	if (searchangle > 2) then searchangle = 0 end
	
	local xoffset = (math.sin(searchangle*math.pi)*radius)
	local yoffset = (math.cos(searchangle*math.pi)*radius)
	
	GRAPHICS.DRAW_LINE(origin.x+(xoffset*0.2), origin.y+(yoffset*0.2), origin.z, center.x+xoffset, center.y+yoffset, center.z, 255, 0, 0, alpha)
end



function szaboattach.tick()

	if (detachcooldown > 0) then detachcooldown = detachcooldown-1 end

	local playerPed = PLAYER.PLAYER_PED_ID()
	local currentVehicle = PED.GET_VEHICLE_PED_IS_IN(playerPed, false)
	
	modecontrol()
	local attachtrg = attachcontrol(currentVehicle)
	
	if (currentVehicle ~= 0 and currentVehicle ~= lastattachedv) then
	--if (currentVehicle ~= 0) then
	
		local curvpos = ENTITY.GET_ENTITY_COORDS(currentVehicle, true)
		
		local isaerial = false
		local raymult = 1
		local curvmodel = ENTITY.GET_ENTITY_MODEL(currentVehicle)
		if (VEHICLE.IS_THIS_MODEL_A_HELI(curvmodel) or VEHICLE.IS_THIS_MODEL_A_PLANE(curvmodel)) then
			isaerial = true
			raymult = 3
		end
		
		local targetpos
		local gb = 255
		if (curmode < 10) then
			if (isaerial) then
				targetpos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(currentVehicle, modes[curmode][1]*raymult*2,raylength*curdir*raymult,modes[curmode][2]*raymult*2)
			else
				targetpos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(currentVehicle, modes[curmode][1]*raymult,raylength*curdir*raymult,modes[curmode][2]*raymult)
			end
		else
			gb = 0
			local searchpos
			if (isaerial) then
				searchpos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(currentVehicle, 0,0,modes[curmode][2]*raymult)
			else
				searchpos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(currentVehicle, 0,modes[curmode][1]*raymult,0)
			end
			local nearv = VEHICLE.GET_CLOSEST_VEHICLE(searchpos.x,searchpos.y,searchpos.z, raylength*raymult, 0, 70)
			if(nearv ~= 0) then
				targetpos = ENTITY.GET_ENTITY_COORDS(nearv, true)
				--GRAPHICS.DRAW_LINE(curvpos.x, curvpos.y, curvpos.z, targetpos.x, targetpos.y, targetpos.z, 255, 0, 0, 250)
			else
				drawradarline(curvpos, searchpos, raylength, 95)
				drawradarline(curvpos, searchpos, raylength, 127)
				drawradarline(curvpos, searchpos, raylength, 159)
				drawradarline(curvpos, searchpos, raylength, 191)
				drawradarline(curvpos, searchpos, raylength, 223)
				drawradarline(curvpos, searchpos, raylength, 255)
			end
		end
		
		if (not targetpos) then return end
		
		-- recyclable pointer
		local midpos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(currentVehicle, 0,raylength/2,0)
		-- pointer
		local hitpos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(currentVehicle, 0,raylength,0)
		
		local ray = WORLDPROBE._CAST_RAY_POINT_TO_POINT(curvpos.x, curvpos.y, curvpos.z, targetpos.x, targetpos.y, targetpos.z, 30, currentVehicle, 0)
		local _, hitent = WORLDPROBE._GET_RAYCAST_RESULT(ray, '', hitpos, midpos, 0)
		
		if (hitent ~= 0) then
			
			if (lastattachedv ~= currentVehicle and attachbutstate and detachcooldown == 0) then
				attachtrg = true
			end
			
			if (get_key_pressed(modekey) or	CONTROLS.IS_CONTROL_PRESSED(2, 190)) then
				attachtrg = false
			end
			
			--GRAPHICS.DRAW_LINE(hitpos.x, hitpos.y, hitpos.z, hitpos.x, hitpos.y, hitpos.z+2, 0, 255, 255, 255)
			
			-- pointer
			local hitbackpos = ENTITY.GET_ENTITY_COORDS(hitent, true)
			
			local backray = WORLDPROBE._CAST_RAY_POINT_TO_POINT(hitpos.x, hitpos.y, hitpos.z, curvpos.x, curvpos.y, curvpos.z, 2, hitent, 0)
			local _, hitbackent = WORLDPROBE._GET_RAYCAST_RESULT(backray, '', hitbackpos, midpos, 0)
			
			local hook2pos = hitpos
			local hook1pos = hitbackpos
			local hooksdist = GAMEPLAY.GET_DISTANCE_BETWEEN_COORDS(hook2pos.x, hook2pos.y, hook2pos.z, hook1pos.x, hook1pos.y, hook1pos.z, true)
			
			--GRAPHICS.DRAW_LINE(hitbackpos.x, hitbackpos.y, hitbackpos.z, hitbackpos.x, hitbackpos.y, hitbackpos.z+2, 255, 0, 255, 255)
			
			if (ENTITY.IS_ENTITY_A_VEHICLE(hitent)) then
				
				-- ugly workaround
				-- if (attachtrg) then VEHICLE.SET_VEHICLE_REDUCE_GRIP(hitent, true) end
				-- end ugly workaround
				
				local othervpos = ENTITY.GET_ENTITY_COORDS(hitent, true)
				local othervposfront = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(hitent, 0,raylength,0)
				local othervposback = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(hitent, 0,-raylength,0)
				
				-- pointer
				local othervcasthit = ENTITY.GET_ENTITY_COORDS(hitent, true)
				
				local snappos = 0
				
				local othervcastray = WORLDPROBE._CAST_RAY_POINT_TO_POINT(othervpos.x, othervpos.y, othervpos.z, othervposfront.x, othervposfront.y, othervposfront.z, 2, hitent, 0)
				local _, othervhitent = WORLDPROBE._GET_RAYCAST_RESULT(othervcastray, '', othervcasthit, midpos, 0)
				if (othervhitent == currentVehicle) then
					snappos = -1
				else
					othervcastray = WORLDPROBE._CAST_RAY_POINT_TO_POINT(othervpos.x, othervpos.y, othervpos.z, othervposback.x, othervposback.y, othervposback.z, 2, hitent, 0)
					_, othervhitent = WORLDPROBE._GET_RAYCAST_RESULT(othervcastray, '', othervcasthit, midpos, 0)
					if (othervhitent == currentVehicle) then snappos = 1 end
				end
				
				
				if (snappos ~= 0) then
					
					--pointer
					local othervbackhit = ENTITY.GET_ENTITY_COORDS(hitent, true)
					
					local othervbackray = WORLDPROBE._CAST_RAY_POINT_TO_POINT(othervcasthit.x, othervcasthit.y, othervcasthit.z, othervpos.x, othervpos.y, othervpos.z, 2, currentVehicle, 0)
					local _, othervhitent = WORLDPROBE._GET_RAYCAST_RESULT(othervbackray, '', othervbackhit, midpos, 0)
					
					hook2pos = othervbackhit
					hook1pos = hitbackpos
					
					hooksdist = GAMEPLAY.GET_DISTANCE_BETWEEN_COORDS(othervbackhit.x, othervbackhit.y, othervbackhit.z, hitbackpos.x, hitbackpos.y, hitbackpos.z, true)
				
				else
					
					hook2pos = hitpos
					hook1pos = hitbackpos
					
				end

				
			elseif (ENTITY.IS_ENTITY_A_PED(hitent)) then
			
				if (attachtrg) then 
					PED.APPLY_DAMAGE_TO_PED(hitent, 262144, true)
				end
				
			end
			
			-- GRAPHICS.DRAW_LINE(hook1pos.x, hook1pos.y, hook1pos.z, hook1pos.x, hook1pos.y, hook1pos.z+2, 255, 0, 255, 255)
			-- GRAPHICS.DRAW_LINE(hook2pos.x, hook2pos.y, hook2pos.z, hook2pos.x, hook2pos.y, hook2pos.z+2, 0, 255, 255, 255)
			
			GRAPHICS.DRAW_LINE(hook1pos.x, hook1pos.y, hook1pos.z-0.3, hook1pos.x, hook1pos.y, hook1pos.z+0.3, 255, 255, 0, 250)
			GRAPHICS.DRAW_LINE(hook1pos.x, hook1pos.y-0.3, hook1pos.z, hook1pos.x, hook1pos.y+0.3, hook1pos.z, 255, 255, 0, 250)
			GRAPHICS.DRAW_LINE(hook1pos.x-0.3, hook1pos.y, hook1pos.z, hook1pos.x+0.3, hook1pos.y, hook1pos.z, 255, 255, 0, 250)
			GRAPHICS.DRAW_LINE(hook2pos.x, hook2pos.y, hook2pos.z-0.3, hook2pos.x, hook2pos.y, hook2pos.z+0.3, 255, gb, 0, 250)
			GRAPHICS.DRAW_LINE(hook2pos.x, hook2pos.y-0.3, hook2pos.z, hook2pos.x, hook2pos.y+0.3, hook2pos.z, 255, gb, 0, 250)
			GRAPHICS.DRAW_LINE(hook2pos.x-0.3, hook2pos.y, hook2pos.z, hook2pos.x+0.3, hook2pos.y, hook2pos.z, 255, gb, 0, 250)
			
			GRAPHICS.DRAW_LINE(hook1pos.x, hook1pos.y, hook1pos.z, hook2pos.x, hook2pos.y, hook2pos.z, 255, 255, 0, 250)
			
			if (attachtrg) then
				--print('attaching vehicle')
				--local hooksdist = GAMEPLAY.GET_DISTANCE_BETWEEN_COORDS(cvhp.x, cvhp.y, cvhp.z, nvhp.x, nvhp.y, nvhp.z, true)
				
				print('attaching. ropelength=',hooksdist)
				
				newrope = ROPE.ADD_ROPE(curvpos.x,curvpos.y,curvpos.z, 0,0,0, hooksdist, 2, hooksdist, 0.1, 		0,true,true,true,0,true,0)
				--	0,0,0  float length, int type, float max_length, float min_length, float p10, BOOL p11, BOOL p12, BOOL p13, float p14, BOOL breakable, Any *p16)
				lastrope = newrope
				lastattachedv = currentVehicle
				
				--VEHICLE.SET_VEHICLE_HANDBRAKE(nearv, false)
				--VEHICLE.SET_VEHICLE_REDUCE_GRIP(nearv, true)
				--VEHICLE.STEER_UNLOCK_BIAS(nearv, true)
				--VEHICLE.SET_VEHICLE_OUT_OF_CONTROL(nearv, true, false)
				--VEHICLE._SET_VEHICLE_ENGINE_POWER_MULTIPLIER(nearv, 0)
				--VEHICLE.SET_VEHICLE_ENGINE_ON(nearv, true, true)
				--VEHICLE.SET_VEHICLE_CAN_BREAK(nearv, false)
				--VEHICLE.SET_VEHICLE_UNDRIVEABLE(nearv, true)
				--VEHICLE.SET_VEHICLE_FRICTION_OVERRIDE(nearv, 10)
				--VEHICLE.SET_VEHICLE_ENGINE_HEALTH(nearv, -5000)
				--VEHICLE.IS_VEHICLE_DRIVEABLE(nearv, false)
				
				ROPE.ATTACH_ENTITIES_TO_ROPE(newrope, currentVehicle, hitent, hook1pos.x, hook1pos.y, hook1pos.z, hook2pos.x, hook2pos.y, hook2pos.z, hooksdist, true,true, 0,0)
				ROPE.ROPE_LOAD_TEXTURES()
				
			end
		else
			--local halwaypos = targetpos - curvpos -- ### vector math not workz
			GRAPHICS.DRAW_LINE(curvpos.x, curvpos.y, curvpos.z, targetpos.x, targetpos.y, targetpos.z, 255, 255, 255, 250)
		end
	end
end
return szaboattach