// SPDX-License-Identifier: GPL-3.0-or-later

public Plugin myinfo =
{
    name = "linux_file_lowercaser_global",
    author = "rtldg / Gemini",
    description = "Global case-sensitivity fix for Linux servers/clients (Issue 865)",
    version = "2.3",
    url = "https://github.com/rtldg/linux_file_lowercaser"
}

#include <sourcemod>
#include <sdktools>
#include <dhooks>

#pragma newdecls required
#pragma semicolon 1

public void OnPluginStart()
{
    GameData gamedata = new GameData("linux_file_lowercaser");
    if (gamedata == null) SetFailState("Couldn't load gamedata for linux_file_lowercaser");

    // 1. High-level filename indexing (Engine Layer)
    DynamicDetour hFindFileName = DynamicDetour.FromConf(gamedata, "CUtlFilenameSymbolTable::FindFileName");
    if (hFindFileName) hFindFileName.Enable(Hook_Pre, Hook_LowerParam1);

    DynamicDetour hFindOrAddFileName = DynamicDetour.FromConf(gamedata, "CUtlFilenameSymbolTable::FindOrAddFileName");
    if (hFindOrAddFileName) hFindOrAddFileName.Enable(Hook_Pre, Hook_LowerParam1);

    // 2. The "Wallhack" and Vertex Format Fix: Global Material Lookup
    DynamicDetour hFindMaterial = DynamicDetour.FromConf(gamedata, "IMaterialSystem::FindMaterial");
    if (hFindMaterial) 
    {
        hFindMaterial.Enable(Hook_Pre, Hook_FindMaterial);
    }
    else 
    {
        PrintToServer("[Lowercaser] Error: Could not find IMaterialSystem::FindMaterial in gamedata.");
    }

    // 3. The Nuclear Option: Direct Filesystem Hook
    // This catches internal texture/shader lookups that bypass the higher-level material system.
    DynamicDetour hFileOpen = DynamicDetour.FromConf(gamedata, "CFileSystem_Stdio::Open");
    if (hFileOpen)
    {
        hFileOpen.Enable(Hook_Pre, Hook_LowerParam1);
    }
    else
    {
        PrintToServer("[Lowercaser] Error: Could not find CFileSystem_Stdio::Open in gamedata.");
    }
}

/**
 * Generic hook for simple path lookups (Engine Symbol Table & Filesystem Open)
 */
public MRESReturn Hook_LowerParam1(DHookReturn ret, DHookParam params)
{
    if (params.IsNull(1)) return MRES_Ignored;

    char buffer[PLATFORM_MAX_PATH];
    params.GetString(1, buffer, sizeof(buffer));

    if (buffer[0] != '\0' && ContainsUppercase(buffer))
    {
        LowercaseString(buffer);
        params.SetString(1, buffer);
        return MRES_ChangedHandled;
    }
    return MRES_Ignored;
}

/**
 * Specific hook for Material System to handle internal search groups.
 * Parameter 2 (pTextureGroupName) is often where "Models" or "MapObjects" lives.
 */
public MRESReturn Hook_FindMaterial(DHookReturn ret, DHookParam params)
{
    char matName[PLATFORM_MAX_PATH];
    char groupName[PLATFORM_MAX_PATH];
    
    params.GetString(1, matName, sizeof(matName)); 
    params.GetString(2, groupName, sizeof(groupName)); 

    bool changed = false;

    if (matName[0] != '\0' && ContainsUppercase(matName))
    {
        LowercaseString(matName);
        params.SetString(1, matName);
        changed = true;
    }

    if (groupName[0] != '\0' && ContainsUppercase(groupName))
    {
        LowercaseString(groupName);
        params.SetString(2, groupName);
        changed = true;
    }

    return (changed) ? MRES_ChangedHandled : MRES_Ignored;
}

/**
 * 4. Dynamic Entity Fix: Ensures prop paths networked to clients are lowercase.
 * This handles static and dynamic props that might have uppercase paths in the BSP.
 */
public void OnEntityCreated(int entity, const char[] classname)
{
    RequestFrame(Task_FixEntityPaths, EntIndexToEntRef(entity));
}

void Task_FixEntityPaths(any data)
{
    int entity = EntRefToEntIndex(data);
    if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity))
        return;

    char buffer[PLATFORM_MAX_PATH];

    if (HasEntProp(entity, Prop_Data, "m_ModelName"))
    {
        GetEntPropString(entity, Prop_Data, "m_ModelName", buffer, sizeof(buffer));
        if (buffer[0] != '\0' && ContainsUppercase(buffer))
        {
            LowercaseString(buffer);
            SetEntPropString(entity, Prop_Data, "m_ModelName", buffer);
        }
    }

    if (HasEntProp(entity, Prop_Send, "m_iszCustomMaterial"))
    {
        GetEntPropString(entity, Prop_Send, "m_iszCustomMaterial", buffer, sizeof(buffer));
        if (buffer[0] != '\0' && ContainsUppercase(buffer))
        {
            LowercaseString(buffer);
            SetEntPropString(entity, Prop_Send, "m_iszCustomMaterial", buffer);
        }
    }
}

/**
 * Helper stocks
 */
stock bool ContainsUppercase(const char[] str)
{
    int i = 0, x;
    while ((x = str[i++]) != 0)
    {
        if ('A' <= x <= 'Z') return true;
    }
    return false;
}

stock void LowercaseString(char[] str)
{
    int i = 0, x;
    while ((x = str[i]) != 0)
    {
        if ('A' <= x <= 'Z')
            str[i] += ('a' - 'A');
        ++i;
    }
}