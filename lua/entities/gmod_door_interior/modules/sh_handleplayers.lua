-- Handles players inside the interior

function ENT:PositionInside(pos)
    if self.ExitBox and (pos:WithinAABox(self:LocalToWorld(self.ExitBox.Min),self:LocalToWorld(self.ExitBox.Max))) then
        return true
    elseif self.ExitDistance and pos:Distance(self:GetPos()) < self.ExitDistance then
        return true
    end
    return false
end

function ENT:GetStuckTrace(ply)
    local pos=ply:GetPos()
    local td={}
    td.start=pos
    td.endpos=pos
    td.mins=ply:OBBMins()
    td.maxs=ply:OBBMaxs()
    -- The StuckFilter hook excludes networked entities so the server and predicting
    -- client build identical filter membership - the predicted unstick must resolve
    -- to the same spot on both.
    local filter={ply}
    for _,e in ipairs(self.stuckfilter or {}) do
        filter[#filter+1]=e
    end
    local extra=self:CallHook("StuckFilter")
    if extra then
        for _,e in ipairs(extra) do
            if IsValid(e) then filter[#filter+1]=e end
        end
    end
    td.filter=filter
    return td --[[@as HullTrace]]
end

function ENT:IsStuck(ply)
    if ply:GetMoveType()==MOVETYPE_NOCLIP then return false end
    local td=self:GetStuckTrace(ply)
    local tr=util.TraceHull(td)
    return tr.Hit
end

-- A separate resolver, not PlayerEnter/PlayerExit: that path writes eye angles
-- (reverts under prediction) and re-fires the entry/exit hooks.
function ENT:ResolveSafePos(ply, exiting)
    -- Find closest floor position within 10 units
    local td=self:GetStuckTrace(ply)
    local oldmaxsz=td.maxs.z
    td.maxs.z=td.mins.z -- Ignore head height for floor snap due to low ceilings
    td.start = td.start + Vector(0,0,10)
    local tr = util.TraceHull(td)
    local newpos = tr.HitPos

    -- Reset trace parameters to check if new position is valid
    td.maxs.z=oldmaxsz
    td.start=newpos
    td.endpos=newpos

    if newpos and not util.TraceHull(td).Hit then
        -- New floor position is valid
        return newpos
    end

    -- No clear floor: use the door's authored fallback safe-spot.
    if IsValid(self.exterior) then
        return self.exterior:ResolveFallbackPos(ply, exiting)
    end
end

if SERVER then
    function ENT:CheckPlayer(ply,portal)
        local inbox = self:PositionInside(ply:GetPos())
        if self.occupants[ply] and not inbox then
            --print("out",self,ply,ply.door,ply.doori)
            self.exterior:PlayerExit(ply,true,IsValid(portal))
            if IsValid(portal) and portal==self.portals.interior and self:IsStuck(ply) then
                --print("stuck out",self,ply,portal)
                local safe = self:ResolveSafePos(ply, true)
                if safe then ply:SetPos(safe) end
            end
            if IsValid(portal) and IsValid(portal.interior) and portal.interior.DoorInterior then
                portal.interior:CheckPlayer(ply)
            end
        elseif not self.occupants[ply] and inbox then
            --print("in",self,ply,ply:GetPos())
            self.exterior:PlayerEnter(ply,true)
            if IsValid(portal) and portal==self.portals.exterior and self:IsStuck(ply) then
                --print("stuck in",self,ply,portal)
                local safe = self:ResolveSafePos(ply, false)
                if safe then ply:SetPos(safe) end
            end
        end
    end
    
    ENT:AddHook("Think", "handleplayers", function(self)
        if not self._init then return end
        for _,v in pairs(player.GetAll()) do
            self:CheckPlayer(v)
        end
    end)

    hook.Add("wp-teleport","doors-handleplayers",function(portal,ent)
        if ent:IsPlayer() then
            for k in pairs(Doors:GetInteriors()) do
                k:CheckPlayer(ent,portal)
            end
        end
    end)
else
    ENT:AddHook("Initialize", "handleplayers", function(self)
        self.occupants=self.exterior.occupants -- Hooray for referenced tables
    end)

    ENT:AddHook("ShouldDraw", "handleplayers", function(self)
        if (LocalPlayer().doori~=self) and not wp.drawing and not self.contains[LocalPlayer().door] then
            return false
        end
    end)

    -- The emerged-half ghost sits at our interior portal, which parks in the skybox
    -- hidden from the open world. Mirror our ShouldDraw so the ghost hides whenever
    -- the interior does, instead of floating in empty sky.
    ENT:AddHook("ShouldDrawGhost", "handleplayers", function(self, ent, ghost, portal, exit)
        if not (self.portals and exit == self.portals.interior) then return end
        if self:CallHook("ShouldDraw") == false then return false end
    end)

    ENT:AddHook("ShouldThink", "handleplayers", function(self)
        if LocalPlayer().doori~=self then
            return false
        end
    end)
end

-- Shared so world-portals' predicted teleport (SetupMove) can veto on the client,
-- not just the server. A consumer's CanPlayerExit veto only predicts if it too is
-- registered shared; a server-only one still works but rubberbands on veto.
ENT:AddHook("ShouldTeleportPortal", "handleplayers", function(self,portal,ent)
    if IsValid(ent) and ent:IsPlayer() and portal==self.portals.interior and self.exterior:CallHook("CanPlayerExit",ent)==false then
        return false
    end
end)

if CLIENT then

    -- Predicted exit (SetupMove): clear the player's door fields. Gate on the main
    -- interior portal - customportals route here too but keep the player inside.
    ENT:AddHook("PostTeleportPortal", "predict", function(self, portal, ent)
        if ent ~= LocalPlayer() then return end
        if not (self.portals and portal == self.portals.interior) then return end
        ent.door = nil
        ent.doori = nil
        if IsValid(self.exterior) and self.exterior.occupants then
            self.exterior.occupants[ent] = nil
        end
        -- Predict the exit unstick so the landing matches the server's. ResolveSafePos
        -- is pure, so re-running it each resim is safe; if not stuck client-side it just
        -- defers to the server.
        if self:IsStuck(ent) then
            local safe = self:ResolveSafePos(ent, true)
            if safe then ent:SetPos(safe) end
        end
    end)

    hook.Add("PrePlayerDraw", "doors-handleplayers", function(ply)
        local int=ply.doori
        if not IsValid(int) then return end
        local localply=LocalPlayer()
        local localplyinside=localply.doori==int
        local drawingportal=wp.drawing and wp.drawingent==int.portals.exterior
        local shoulddraw=int:CallHook("ShouldDrawPlayer", ply, localply)
        if (not localplyinside or shoulddraw==false) and not drawingportal then
            return true
        end
    end)

    hook.Add("DrawPhysgunBeam", "doors-handleplayers", function(ply)
        local int=ply.doori
        if not IsValid(int) then return end
        local localply=LocalPlayer()
        local localplyinside=localply.doori==int
        local drawingportal=wp.drawing and wp.drawingent==int.portals.exterior
        local shoulddraw=int:CallHook("ShouldDrawPlayer", ply, localply)
        if (not localplyinside or shoulddraw==false) and not drawingportal then
            return false
        end
    end)
end