# Regenerates two generated hook-type artefacts, so hook callbacks type their payload
# params without a manual ---@param. Auto-generated. CI: generate-hook-types.yml.
#   1. the AddHook ---@overload catalogue in each entity's shared.lua (from CallHook sites)
#   2. types/doors_hook_overloads.lua (from Doors' custom hook.Call sites), spliced into
#      the glua-api hook.lua by Initialize-GmodTools so hook.Add("Doors-...", fn) types.
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/bootstrap.ps1"

$root = Split-Path -Parent $PSScriptRoot
Build-HookTypeCatalogue -Root $root
Build-GlobalHookOverloads -Root $root -Id doors -Owns 'Doors-*', 'SkinChanged', 'BodygroupChanged'
