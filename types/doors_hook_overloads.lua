-- Generated custom global-hook overloads. Do not edit; regen: scripts/generate-hook-types.ps1.
-- Sync-GmodHookTypes (Initialize-GmodTools) splices these into .tools/glua-api/hook.lua so
-- hook.Add("<name>", ...) callbacks type their payload params. Inert on its own - the splice binds.

---@param eventName string
---@param identifier any
---@param func function
---@overload fun(eventName: "BodygroupChanged", identifier: any, func: fun(ent: Entity, bodygroup: number, value: number, arg4: any, ...))
---@overload fun(eventName: "Doors-ExteriorAdded", identifier: any, func: fun(e: gmod_door_exterior, ...))
---@overload fun(eventName: "Doors-ExteriorRemoved", identifier: any, func: fun(e: gmod_door_exterior, ...))
---@overload fun(eventName: "Doors-InteriorAdded", identifier: any, func: fun(e: gmod_door_interior, ...))
---@overload fun(eventName: "Doors-InteriorRemoved", identifier: any, func: fun(e: gmod_door_interior, ...))
---@overload fun(eventName: "SkinChanged", identifier: any, func: fun(ent: Entity, i: number, arg3: any, ...))
function hook.Add(eventName, identifier, func) end
