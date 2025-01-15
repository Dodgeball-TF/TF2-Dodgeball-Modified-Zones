#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

// Don't touch this (Plugin information)
#define PLUGIN_NAME "ZonePoints"
#define PLUGIN_AUTH "Tolfx"
#define PLUGIN_DESC "Points for people inside the zone"
#define PLUGIN_VERS "0.0.1"
#define PLUGIN_WURL ""  // BEING BUILT

#define ZONE_NAME   "DodgeballZone"

ConVar PluginEnabled;

int    PlayerInsideZone[MAXPLAYERS + 1];
int    g_longestPlayer  = -1;
int    g_particleEffect = -1;

public Plugin myinfo =
{
  name        = PLUGIN_NAME,
  author      = PLUGIN_AUTH,
  description = PLUGIN_DESC,
  version     = PLUGIN_VERS,
  url         = PLUGIN_WURL
};

public OnPluginStart()
{
  PluginEnabled = CreateConVar("tfzones_points_enabled", "1", "Should this plugin be enabled?", _, true, 0.0, true, 1.0);

  HookEvent("player_death", OnPlayerDeath);
}

public void OnPlayerDeath(Event event, char[] eventName, bool dontBroadcast)
{
  if (!PluginEnabled.BoolValue)
  {
    return;
  }

  int client = GetClientOfUserId(GetEventInt(event, "userid"));

  if (client == g_longestPlayer)
  {
    SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
    if (g_particleEffect != -1)
    {
      DeleteParticle(g_particleEffect);
      SDKUnhook(g_particleEffect, SDKHook_SetTransmit, TransmitParticleEffect);
      g_particleEffect = -1;
    }
    g_longestPlayer = -1;
  }

  PlayerInsideZone[client] = 0;
}

public Action fuckZones_OnStartTouchZone(int client, int entity, const char[] zone_name, int type)
{
  if (!PluginEnabled.BoolValue)
  {
    return Plugin_Continue;
  }

  if (strcmp(zone_name, ZONE_NAME, false) != 0)
  {
    return Plugin_Continue;
  }

  PlayerInsideZone[client] = GetTime();

  return Plugin_Continue;
}

public Action fuckZones_OnEndTouchZone(int client, int entity, const char[] zone_name, int type)
{
  if (!PluginEnabled.BoolValue)
  {
    return Plugin_Continue;
  }

  if (strcmp(zone_name, ZONE_NAME, false) != 0)
  {
    return Plugin_Continue;
  }

  // int    timeInZone   = GetTime() - PlayerInsideZone[client];
  // int    pointsToGive = timeInZone / 10;
  // Handle customEvent  = CreateEvent("player_escort_score", true);
  // SetEventInt(customEvent, "player", client);
  // SetEventInt(customEvent, "points", pointsToGive);
  // FireEvent(customEvent);
  // CloseHandle(customEvent);

  PlayerInsideZone[client] = 0;

  if (client == g_longestPlayer)
  {
    SetEntProp(client, Prop_Send, "m_bGlowEnabled", 0);
    if (g_particleEffect != -1)
    {
      DeleteParticle(g_particleEffect);
      SDKUnhook(g_particleEffect, SDKHook_SetTransmit, TransmitParticleEffect);
      g_particleEffect = -1;
    }
    g_longestPlayer = -1;
  }

  return Plugin_Continue;
}

public void OnGameFrame()
{
  if (!PluginEnabled.BoolValue)
  {
    return;
  }

  int longestTime   = 0;
  int longestPlayer = -1;

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && IsPlayerAlive(i) && PlayerInsideZone[i])
    {
      int timeInZone = GetTime() - PlayerInsideZone[i];
      if (timeInZone > longestTime)
      {
        longestTime   = timeInZone;
        longestPlayer = i;
      }
    }
  }

  if (g_longestPlayer != -1 && g_longestPlayer != longestPlayer)
  {
    SetEntProp(g_longestPlayer, Prop_Send, "m_bGlowEnabled", 0);
    if (g_particleEffect != -1)
    {
      DeleteParticle(g_particleEffect);
      SDKUnhook(g_particleEffect, SDKHook_SetTransmit, TransmitParticleEffect);
      g_particleEffect = -1;
    }
  }

  if (longestPlayer != -1)
  {
    SetEntProp(longestPlayer, Prop_Send, "m_bGlowEnabled", 1);
    if (g_particleEffect == -1)
    {
      // merasmus_tp <-- cool effect
      g_particleEffect = CreateParticle("spellbook_rainbow", longestPlayer);
      SDKHook(g_particleEffect, SDKHook_SetTransmit, TransmitParticleEffect);
    }
  }

  g_longestPlayer = longestPlayer;
}

stock Action TransmitParticleEffect(int particleEffect, int other)
{
  if (g_longestPlayer == other)
  {
    return Plugin_Handled;
  }

  return Plugin_Continue;
}

stock int CreateParticle(char[] type, int entity)
{
  int particle = CreateEntityByName("info_particle_system");

  if (IsValidEdict(particle))
  {
    float pos[3];

    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", pos);
    // pos[2] += 105.0;  // Move the effect higher up

    TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
    DispatchKeyValue(particle, "effect_name", type);

    SetVariantString("!activator");
    AcceptEntityInput(particle, "SetParent", entity, particle, 0);

    char targetName[255];
    Format(targetName, sizeof(targetName), "zone_point_effect_%i", entity);
    DispatchKeyValue(particle, "targetname", targetName);

    DispatchSpawn(particle);
    ActivateEntity(particle);
    AcceptEntityInput(particle, "Start");

    SetEdictFlags(particle, GetEdictFlags(particle) & (~FL_EDICT_ALWAYS));

    return particle;
  }

  return -1;
}

stock Action DeleteParticle(int particle)
{
  if (IsValidEdict(particle))
  {
    char classname[64];
    GetEdictClassname(particle, classname, sizeof(classname));

    if (StrEqual(classname, "info_particle_system", false))
    {
      AcceptEntityInput(particle, "Stop");
      RemoveEdict(particle);
    }
  }

  return Plugin_Handled;
}