local PLAYER = FindMetaTable("Player")

hook.Add("EntityNetworkedVarChanged", "SlashCoImpervious", function(ent, name, _, new)
	if name ~= "IsImpervious" then return end

	ent.IsImpervious = new
	ent:SetCustomCollisionCheck(new or false)
	ent:CollisionRulesChanged()
end)

hook.Add("ShouldCollide", "SlashCoImpervious", function(ent1, ent2)
	if not ent1.IsImpervious and not ent2.IsImpervious then
		return
	end

	if (ent1:IsPlayer() or ent1:GetClass() == "prop_door_rotating") and (ent2:IsPlayer() or ent2:GetClass() == "prop_door_rotating") then
		--i would put a check for if doors were locked here but the locked state of doors could change
		--see the warning in https://wiki.facepunch.com/gmod/GM:ShouldCollide to see why this matters
		return false
	end
end)

function PLAYER:SetImpervious(state)
	if state then
		if self.IsImpervious then
			return
		end

		self:SetCustomCollisionCheck(true)
		self:SetNW2Bool("IsImpervious", true)

		local userid = self:UserID()
	else
		if not self.IsImpervious then
			return
		end

		self:SetCustomCollisionCheck(false)
		self:SetNW2Bool("IsImpervious", false)
		hook.Remove("ShouldCollide", "SlashCoImpervious_" .. self:UserID())
	end
end

hook.Add("PlayerDeath", "slashCoRemoveImpervious", function(victim)
	victim:SetImpervious(false)
end)
