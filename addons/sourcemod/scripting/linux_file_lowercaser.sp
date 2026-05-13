// SPDX-License-Identifier: GPL-3.0-or-later

public Plugin myinfo =
{
    name = "linux_file_lowercaser_global",
    author = "rtldg / Gemini",
    description = "Global case-sensitivity fix for Linux servers/clients (Issue 865)",
    version = "2.0",
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

    // 1. High-level filename indexing
    DynamicDetour.FromConf(gamedata, "CUtlFilenameSymbolTable::FindFileName").Enable(Hook_Pre, Hook_LowerParam1);
    DynamicDetour.FromConf(gamedata, "CUtlFilenameSymbolTable::FindOrAddFileName").Enable(Hook_Pre, Hook_LowerParam1);

    // 2. The "Wallhack" Fix: Global Material Lookup
    DynamicDetour hFindMaterial = DynamicDetour.FromConf(gamedata, "IMaterialSystem::FindMaterial");
    if (hFindMaterial) 
    {
        hFindMaterial.Enable(Hook_Pre, Hook_LowerParam1);
    }
    else 
    {
        PrintToServer("[Lowercaser] Warning: Could not find IMaterialSystem::FindMaterial in gamedata.");
    }
}

// Global hook for any function where the first parameter is a path/filename
public MRESReturn Hook_LowerParam1(DHookReturn ret, DHookParam params)
{
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

// 3. Dynamic Entity Fix: Handles props/entities as they spawn
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

    // Fix Prop Models
    if (HasEntProp(entity, Prop_Data, "m_ModelName"))
    {
        GetEntPropString(entity, Prop_Data, "m_ModelName", buffer, sizeof(buffer));
        if (buffer[0] != '\0' && ContainsUppercase(buffer))
        {
            LowercaseString(buffer);
            SetEntPropString(entity, Prop_Data, "m_ModelName", buffer);
        }
    }

    // Fix Custom Material Overrides
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