freeslot("MT_S5_MISSILE",
		 "S_SLIDE_EXIT", "S_MISSILE_WANDER", "S_MISSILE_LOCK_ON", "S_MISSILE_JUMP", "S_SLIDE", "S_SLIDE_EXIT",
	     "SPR2_MJMP", "SPR2_SLDE");
states[S_SLIDE] = {
	sprite = SPR_PLAY,
	frame = SPR2_SLDE,
	tics = -1,
}

states[S_MISSILE_JUMP] = {
	sprite = SPR_PLAY,
	frame = SPR2_MJMP,
	tics = 20,
	nextstate = S_PLAY_FALL,
	action = A_PlaySound,
	var1 = sfx_rlaunc
}
states[S_MISSILE_LOCK_ON] = {
	sprite = SPR_RCKT,
}
states[S_MISSILE_WANDER] = {
	sprite = SPR_TORP,
	tics = 1000,
}
mobjinfo[MT_S5_MISSILE] = {
	spawnstate = S_MISSILE_WANDER,
	deathstate = MT_TORPEDO,
	speed = 15*FRACUNIT,
	flags = MF_MISSILE|MF_NOGRAVITY	
}

local MISS_MAX_DIST = 300*FRACUNIT
local shouldSld = false
local shouldMs = false
local SLIDE_COOL_DOWN = 2*TICRATE

-- Stops sliding
local function undoSlide(player)
-- 	local player = mobj.player
	print("Exiting")
-- 	player.height = skins[player.mo.skin].height
	player.charflags = $&~SF_CANBUSTWALLS
	player.pflags = $&~PF_SPINNING
	player.mo.state = S_PLAY_WALK
	player.mo.friction = 29*FRACUNIT/32
end

-- Performs Slide ability on spin if on the ground
local function slide(player)
	if(not (skins[player.mo.skin].name == "subject5")
	or not (P_IsObjectOnGround(player.mo))) then 
		return
	end
	-- Thrusting when sliding once
	// and not (player.speed <= 3*FRACUNIT)
	if(not (player.mo.state == S_SLIDE) 
		and not (player.pflags & PF_SPINDOWN)) then
		player.pflags = $|PF_SPINNING
		player.mo.state = S_SLIDE
	-- When using ability again during the ability
	elseif(player.mo.state == S_SLIDE
		and not (player.pflags & PF_SPINDOWN)) then
		player.mo.state = S_PLAY_WALK
	end
end

local function tryResetMissiles(player)
	-- Reset Missile Swarp 
	if(P_IsObjectOnGround(player.mo)) then
		shouldMs = true
	end
end

-- Tries to replace a wandering missile with lock-on missile
local function tryMissileLock(wMissile)
	if(wMissile.valid and wMissile.state == S_MISSILE_WANDER) then 
		searchBlockmap("objects", 
						-- source: wandering missile mobj to be replaced 
						-- dest: a mobj that was found
						function (source, dest) 
							-- if any of it is true, don't lock-on 
							if(dest.type == MT_S5_MISSILE
							or source.target == dest
							or not (dest.lock == nil)
							or not P_CheckSight(source, dest)
							or not (dest.flags & MF_ENEMY)) then
								return;
							end
							-- Creates a lock on missile
							local swndM = P_SpawnMissile(source, dest, MT_S5_MISSILE);
							if(swndM == nil) then
								return;
							end
							swndM.target = source.target;
							swndM.lock = dest;
							dest.lock = swndM;
							-- Replacing wandering missile for a lock on missile
							swndM.state = S_MISSILE_LOCK_ON;
							P_RemoveMobj(source);
						end,
						wMissile, 
						wMissile.x - MISS_MAX_DIST, 
						wMissile.x + MISS_MAX_DIST, 
						wMissile.y - MISS_MAX_DIST, 
						wMissile.y + MISS_MAX_DIST);
	end
end

local function ignoreMissileDmg(target, inflictor, source, damage, damagetype)
	if(target.type == MT_PLAYER and inflictor.type == MT_S5_MISSILE) then
		return false
	end
end;

-- Doesn't work
local function removeLockOn(mobj)
	if(not !mobj.lock) then
		print("lock was nil?")
		return
	end
	local mobj1 = mobj.lock
	mobj.lock = nil
	if(not !mobj.lock) then
		print("another lock was nil")
		return
	end
	mobj1.lock = nil
end

-- Double Jumps and shoots missiles in all directions
local function missileSwarm(player) 
	if(not player.mo.name == "subject5" or
	shouldMs == false) then 
		return false
	end
	player.mo.state = S_MISSILE_JUMP
	for i = 0, 3 do
		 P_SPMAngle(player.mo, MT_S5_MISSILE, player.mo.angle + FixedAngle(i*90*FRACUNIT))
	end
	
	-- Vertical Boost for player
	P_SetObjectMomZ(player.mo, FixedMul(10*FRACUNIT, player.mo.scale));

	shouldMs = false
	return true
end

-- local function changeHeight(player)
-- 	if(player.pflags & PF_SPINNING) then
-- 		player.mo.height = P_GetPlayerSpinHeight(player)
-- 	elseif(player.pflags & ~PF_SPINNING) then
-- 		player.mo.height = skins[player.mo.skin].height
-- 	end
-- end
addHook("PlayerThink", function(player)
	-- Stop function if the player is not Subjct5
	if(player.mo.skin ~= "subject5") then 
		return	
	end
	-- When leaving a slide state
	if(player.mo.prevstate == S_SLIDE 
	and player.mo.state ~= S_SLIDE) then
-- 		count2()
		undoSlide(player)
	end
	tryResetMissiles(player)
	
	player.mo.prevstate = player.mo.state
end)

addHook("MobjCollide", 
		function(collidingWith, missile)
			removeLockOn(missile)
		end,
		MT_S5_MISSILE)

addHook("MobjDeath", 
		function(missile, p1, p2, p3) 
			removeLockOn(missile)
		end,
		MT_S5_MISSILE)
			
-- When player colliding with the enemy
addHook("MobjCollide", 
		function(thing, thing2)
			if(thing.state == S_SLIDE
			and thing2.flags & MF_ENEMY) then
				P_InstaThrust(thing2, 
							   thing.player.drawangle, 
							   FixedMul(20, thing.player.speed))
			end
		end, 
		MT_PLAYER)
		
-- Use ability Swarm on Jump key pressed in the air
addHook("AbilitySpecial", missileSwarm);
-- Slide on spin key hold
addHook("SpinSpecial", slide)

-- Tries to replace a wandering missile with lock-on missile
addHook("MobjThinker", tryMissileLock, MT_S5_MISSILE);
-- Ignores specific missile targets
addHook("ShouldDamage", ignoreMissileDmg, MS_S5_MISSILE);