#pragma semicolon 1
#pragma newdecls required

#include <builtinvotes>
#include <colors>
#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <confogl>

#define L4D2Team_Spectator 1

Handle g_hVote;
char   g_sSlots[32];
ConVar hMaxSlots;
int    MaxSlots;

ConVar L4DToolz_MaxPlayers;
ConVar L4DToolz_VisibleMaxPlayers;
ConVar g_hMaxPlayers;

ConVar g_cvSurvivorLimit;
ConVar g_cvInfectedLimit;

public Plugin myinfo =
{
    name        = "Slots?! Voter",
    description = "Slots Voter",
    author      = "Sir",
    version     = "",
    url         = "https://github.com/SirPlease/L4D2-Competitive-Rework/"
};

public void OnPluginStart()
{
    LoadTranslations("slots_vote.phrases");
    RegConsoleCmd("sm_slots", SlotsRequest);

    g_cvSurvivorLimit = FindConVar("survivor_limit");
    g_cvInfectedLimit = FindConVar("z_max_player_zombies");

    hMaxSlots = CreateConVar("slots_max_slots", "30", "Maximum amount of slots you wish players to be able to vote for? (DON'T GO HIGHER THAN 30)", _, true, 1.0, true, 30.0); // we just prevent going higher with minimum/maximum values
    MaxSlots  = hMaxSlots.IntValue;
    hMaxSlots.AddChangeHook(CvChg_MaxSlotsChanged);

    L4DToolz_MaxPlayers = FindConVar("sv_maxplayers");
    L4DToolz_VisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");

    g_hMaxPlayers = CreateConVar("mv_maxplayers", "-1", "How many slots would you like the Server to be at Config Load/Unload? (DON'T GO HIGHER THAN 30)", _, true, 1.0, true, 30.0); // we just prevent going higher with minimum/maximum values
    g_hMaxPlayers.IntValue = L4DToolz_MaxPlayers.IntValue;

    L4DToolz_MaxPlayers.AddChangeHook(CvChg_MaxPlayersChanged);
    L4DToolz_VisibleMaxPlayers.AddChangeHook(CvChg_MaxPlayersChanged);
    g_hMaxPlayers.AddChangeHook(CvChg_MaxPlayersChanged);
}

public Action SlotsRequest(int client, int args)
{
    if (client == 0)
    {
        ReplyToCommand(client, "%T", "NotConsoleVote", LANG_SERVER);
        return Plugin_Handled;
    }

    if (args == 0)
    {
        CPrintToChat(client, "%t %t", "Tag", "SlotsUsage");
        return Plugin_Handled;
    }

    char sSlots[64];
    GetCmdArg(1, sSlots, sizeof(sSlots));
    int Int = StringToInt(sSlots);
    if (Int > MaxSlots)
    {
        CPrintToChat(client, "%t %t", "Tag", "LimitSlotsAbove", MaxSlots);
    }
    else
    {
        if (GetUserFlagBits(client) & ADMFLAG_GENERIC)
        {
            char sName[MAX_NAME_LENGTH];
            GetClientName(client, sName, sizeof(sName));
            CPrintToChatAll("%t %t", "Tag", "LimitedSlotsTo", sName, Int);
            g_hMaxPlayers.IntValue = Int;
        }
        else if (Int < (g_cvSurvivorLimit.IntValue + g_cvInfectedLimit.IntValue))
        {
            CPrintToChat(client, "%t %t", "Tag", "RequiredPlayers");
        }
        else if (StartSlotVote(client, sSlots))
        {
            strcopy(g_sSlots, sizeof(g_sSlots), sSlots);
            FakeClientCommand(client, "Vote Yes");
        }
    }

    return Plugin_Handled;
}

bool StartSlotVote(int client, char[] Slots)
{
    if (GetClientTeam(client) <= L4D2Team_Spectator)
    {
        CPrintToChat(client, "%t %t", "Tag", "Spectators");
        return false;
    }

    if (!IsBuiltinVoteInProgress())
    {
        int iNumPlayers = 0;
        int[] iPlayers  = new int[MaxClients];

        // list of non-spectators players
        for (int i = 1; i <= MaxClients; i++)
        {
            if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= L4D2Team_Spectator)
            {
                continue;
            }

            iPlayers[iNumPlayers++] = i;
        }

        char sBuffer[64];
        Format(sBuffer, sizeof(sBuffer), "%T", "LimitSlots", LANG_SERVER, Slots);

        g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
        SetBuiltinVoteArgument(g_hVote, sBuffer);
        SetBuiltinVoteInitiator(g_hVote, client);
        SetBuiltinVoteResultCallback(g_hVote, SlotVoteResultHandler);
        DisplayBuiltinVote(g_hVote, iPlayers, iNumPlayers, 20);
        return true;
    }

    CPrintToChat(client, "%t %t", "Tag", "CannotBeStarted");
    return false;
}

public void VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
    switch (action)
    {
        case BuiltinVoteAction_End:
        {
            delete vote;
            g_hVote = null;
        }
        case BuiltinVoteAction_Cancel:
        {
            DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
        }
    }
}

public void SlotVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    for (int i = 0; i < num_items; i++)
    {
        if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
        {
            if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
            {
                int Slots = StringToInt(g_sSlots, 10);
                char Buffer[32];
                Format(Buffer, sizeof(Buffer), "%T", "LimitingSlots", LANG_SERVER);
                DisplayBuiltinVotePass(vote, Buffer);

                g_hMaxPlayers.IntValue = Slots;
                return;
            }
        }
    }
    DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public void CvChg_MaxSlotsChanged(ConVar cvar, char[] oldValue, char[] newValue)
{
    MaxSlots = hMaxSlots.IntValue;
}

public void CvChg_MaxPlayersChanged(ConVar cvar, char[] oldValue, char[] newValue)
{
    L4DToolz_MaxPlayers.IntValue = g_hMaxPlayers.IntValue;
    L4DToolz_VisibleMaxPlayers.IntValue = g_hMaxPlayers.IntValue;
}

public void LGO_OnMatchModeLoaded()
{
    g_hMaxPlayers.IntValue = hMaxSlots.IntValue;
}

public void LGO_OnMatchModeUnloaded()
{
    g_hMaxPlayers.IntValue = hMaxSlots.IntValue;
}