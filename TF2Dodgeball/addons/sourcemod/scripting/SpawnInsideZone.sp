#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include "fuckZones"

#define PLUGIN_NAME "SpawnInsideZone"
#define PLUGIN_AUTH "Tolfx"
#define PLUGIN_DESC "Spawns players inside zone automatic"
#define PLUGIN_VERS "0.0.1"
#define PLUGIN_WURL ""

#define ZONE_SPAWNS "DodgeballZoneSpawn_"

ConVar    PluginEnabled;

Cookie    CookieAutoSpawnPlayer;
int       AutoSpawnPlayer[MAXPLAYERS + 1];

ArrayList TeleportZones;

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
  PluginEnabled         = CreateConVar("tfzones_spawn_inside_enabled", "1", "Should this plugin be enabled?", _, true, 0.0, true, 1.0);
  CookieAutoSpawnPlayer = RegClientCookie("tfzones_spawn_autospawn", "Does client want to autospawn inside zone?", CookieAccess_Public);

  RegConsoleCmd("sm_autospawn", AutoSpawnCommand, "Automatically spawn inside the zone");
  HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);

  TeleportZones  = new ArrayList(64);

  bool fuckZones = LibraryExists("fuckZones");

  if (fuckZones)
  {
    AddZonesToList();
  }

  for (int i = 1; i <= MaxClients; i++)
  {
    if (IsValidClient(i))
    {
      OnClientCookiesCached(i);
    }
  }
}

public void OnLibraryAdded(const char[] name)
{
  if (StrEqual(name, "fuckZones"))
  {
    AddZonesToList();
  }
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
  if (!PluginEnabled.BoolValue)
  {
    return Plugin_Continue;
  }

  int client = GetClientOfUserId(event.GetInt("userid"));

  if (!AutoSpawnPlayer[client])
  {
    return Plugin_Continue;
  }

  int zoneCount = TeleportZones.Length;
  if (zoneCount == 0)
  {
    return Plugin_Continue;
  }

  int  randomIndex = GetRandomInt(0, zoneCount - 1);

  char zoneName[256];
  TeleportZones.GetString(randomIndex, zoneName, sizeof(zoneName));

  fuckZones_TeleportClientToZone(client, zoneName);

  return Plugin_Continue;
}

public Action AutoSpawnCommand(int client, int args)
{
  if (!IsValidClient(client))
  {
    return Plugin_Handled;
  }

  if (AutoSpawnPlayer[client])
  {
    AutoSpawnPlayer[client] = 0;
    PrintToChat(client, "Auto-spawn inside zone disabled.");
  }
  else
  {
    AutoSpawnPlayer[client] = 1;
    PrintToChat(client, "Auto-spawn inside zone enabled.");
  }

  SetClientCookie(client, CookieAutoSpawnPlayer, AutoSpawnPlayer[client] ? "1" : "0");

  return Plugin_Handled;
}

public void OnClientAuthorized(int client, const char[] auth)
{
  char value[12];
  GetClientCookie(client, CookieAutoSpawnPlayer, value, sizeof(value));

  if (strlen(value) == 0)
  {
    AutoSpawnPlayer[client] = 0;
    SetClientCookie(client, CookieAutoSpawnPlayer, "0");
  }
  else
  {
    AutoSpawnPlayer[client] = (StrEqual(value, "1")) ? 1 : 0;
  }
}

public void OnClientCookiesCached(int client)
{
  char value[12];
  GetClientCookie(client, CookieAutoSpawnPlayer, value, sizeof(value));

  if (strlen(value) == 0)
  {
    AutoSpawnPlayer[client] = 0;
    SetClientCookie(client, CookieAutoSpawnPlayer, "0");
  }
  else
  {
    AutoSpawnPlayer[client] = (StrEqual(value, "1")) ? 1 : 0;
  }
}

stock bool IsValidClient(int iClient, bool bAlive = false)
{
  return iClient >= 1 && iClient <= MaxClients && IsClientInGame(iClient) && (!bAlive || IsPlayerAlive(iClient));
}

public void fuckZones_OnZoneCreate(int entity, const char[] zone_name, int type)
{
  if (StrContains(zone_name, ZONE_SPAWNS) == 0)
  {
    char existingZone[256];
    bool zoneExists = false;

    for (int i = 0; i < TeleportZones.Length; i++)
    {
      TeleportZones.GetString(i, existingZone, sizeof(existingZone));
      if (StrEqual(existingZone, zone_name))
      {
        zoneExists = true;
        break;
      }
    }

    if (!zoneExists)
    {
      TeleportZones.PushString(zone_name);
    }
  }
}

void AddZonesToList()
{
  ArrayList zoneList  = fuckZones_GetZoneList();
  int       zoneCount = zoneList.Length;
  for (int i = 0; i < zoneCount; i++)
  {
    char zoneName[256];
    int  zone = EntRefToEntIndex(zoneList.Get(i));
    fuckZones_GetZoneName(zone, zoneName, sizeof(zoneName));
    if (StrContains(zoneName, ZONE_SPAWNS) == 0)
    {
      char existingZone[256];
      bool zoneExists = false;

      for (int x = 0; x < TeleportZones.Length; x++)
      {
        TeleportZones.GetString(x, existingZone, sizeof(existingZone));
        if (StrEqual(existingZone, zoneName))
        {
          zoneExists = true;
          break;
        }
      }

      if (!zoneExists)
      {
        TeleportZones.PushString(zoneName);
      }
    }
  }
  delete zoneList;
}