#include <sourcemod>

#define PLUGIN_VERSION "1.0.0"
#define AUTHORS "zeThijs"
#define PREFIX "\x04[MapCFGs - by zeThijs]\x01 "

Handle custom_Cvars;
float stepsize = 0.5;
bool mapcfg_exists = false;
bool CVarsChanged = false;

public Plugin myinfo =
{
	name = PREFIX,
	author = AUTHORS,
	description = "In game configurable cvar map configs",
	version = PLUGIN_VERSION,
	url = "https://github.com/zeThijs?tab=repositories"
};


public void OnPluginStart()
{
    custom_Cvars = CreateTrie();
    RegServerCmd("sm_getmapcfg", a_getmapcfg, "debug");
    RegServerCmd("sm_savemapcfg", a_SaveMapCFG, "debug");
    RegServerCmd("sm_printmapcfg", PrintMapCfg, "debug");
    RegAdminCmd("sm_mapconfig", CB_CVar, ADMFLAG_KICK, "sets and save a custom cvar");
    RegServerCmd("sm_mapconfigserver", CB_CVarServer, "sets and save a custom cvar");
}


public OnMapEnd() 
{
    SaveMapCFG();
}

//note to self: OnMapStart is loaded OnPluginStart if plugin reloaded
public void OnMapStart(){
    ClearTrie(custom_Cvars);
    CVarsChanged = false;
	GetMapCFG();
}


//Read current map’s cvar configs from mapname.cfg, if found. Store data in custom_Cvars trie 
//If not found, return 1
int GetMapCFG()
{   
    char path[PLATFORM_MAX_PATH];
    Format(path, sizeof(path), "cfg/");

	char map[128];
    GetCurrentMap(map, sizeof(map));

    StrCat(path, sizeof(path), map);
    StrCat(path, sizeof(path), ".cfg");

    mapcfg_exists = FileExists(path);
    if (mapcfg_exists)
	{
        //read cfg file and save into trie.
		PrintToServer("%s Loading Map Config", PREFIX);
	}

    //root directory is mod/cfg, which is the dir we need for map configs
	File file = OpenFile(path, "r");
    if (file==null)
    {
        PrintToServer("Error unable to open map cfg: %s", path);
        return 1;
    }
    else
        PrintToServer("Successfully loaded: %s", path);

    char line[PLATFORM_MAX_PATH];
    
    while( !IsEndOfFile( file ) && ReadFileLine( file, line, sizeof( line ) ) )
    {
        char exploded[3][64];
        ExplodeString(line, " ", exploded, 3, 64 );
        if (StrEqual(exploded[0], "sm_cvar")) 
        {
            //remove unnecessary characters
            for (int i=1; i<3; i++)
            {
                // ReplaceString(exploded[i], 64, "\"", "", false);
                ReplaceString(exploded[i], 64, "\n", "", false);
            }
            SetTrieString(custom_Cvars, exploded[1], exploded[2], true);
        }
    }
   delete file;
}

//debug
public Action PrintMapCfg(int args)
{
    Handle keys = CreateTrieSnapshot(custom_Cvars);
    {
        int length = TrieSnapshotLength(keys);
        char buffer[64];
        char buffer2[64];

        for (int i = 0; i < length; ++i)
        {
            GetTrieSnapshotKey(keys, i, buffer, sizeof(buffer));
            GetTrieString(custom_Cvars, buffer, buffer2, sizeof(buffer2));
            PrintToServer("buffer = %s, %s", buffer, buffer2);
        }
    }
}


//Set map density cfg
int SaveMapCFG()
{

    if (!CVarsChanged)
    {
        PrintToServer("%s No CVars changed, skipping modcfg cvar saving..", PREFIX);
        return 0;
    }

    char path[PLATFORM_MAX_PATH];
    Format(path, sizeof(path), "cfg/");

	char map[128];
    GetCurrentMap(map, sizeof(map));

    StrCat(path, sizeof(path), map);
    StrCat(path, sizeof(path), ".cfg");

    char fileStrBuff[1024];
    mapcfg_exists = FileExists(path);
    if (mapcfg_exists)
	{
        //root directory is mod/cfg, which is the dir we need for map configs
        File file = OpenFile(path, "r");
        if (file!=null)
            PrintToServer("%s Successfully read: %s", PREFIX, path);

        char line[PLATFORM_MAX_PATH];
        //create file string which exclude cvar entres
        while( !IsEndOfFile( file ) && ReadFileLine( file, line, sizeof( line ) ) )
        {
            if ( StrContains(line, "sm_cvar", false) != -1 )
                continue;
            
            StrCat(line, sizeof(line), "\n");
            StrCat(fileStrBuff, sizeof(fileStrBuff), line);
        }
        delete file;
    }
    else
        PrintToServer("%s %s does not exist, creating a new one.", PREFIX, path);


    //add cvars to filestring
    Handle keys = CreateTrieSnapshot(custom_Cvars);
    {
        int length = TrieSnapshotLength(keys);
        char buffer[64];
        char buffer2[64];

        for (int i = 0; i < length; ++i)
        {
            GetTrieSnapshotKey(keys, i, buffer, sizeof(buffer));
            GetTrieString(custom_Cvars, buffer, buffer2, sizeof(buffer2));

            Format(buffer, sizeof(buffer), "sm_cvar %s %s\n", buffer, buffer2);
            StrCat(fileStrBuff, sizeof(fileStrBuff), buffer);
        }
    }

    //write da file
    File file = OpenFile(path, "w");
    if (file==null)
    {
        PrintToServer("%s Error writing new map cfg: %s", PREFIX, path);
        delete file;
        return 1;
    }
    else
    {
        if ( WriteFileString(file, fileStrBuff, false))
            PrintToServer("%s successfully wrote new mapcfg file", PREFIX);
        else
            PrintToServer("%s Error writing new map cfg: %s", PREFIX, path);
    }
    delete file;
    delete keys;
}






public Action CB_CVar(int client, int args)
{

    //Get command cvar input
    char cvar[64];
    char value[64];
  
    if (args != 2)
    {
        PrintToChat(client, "Usage: sm_cvar <cvar> <value>");
        return Plugin_Handled;
    }

    GetCmdArg(1, cvar, sizeof(cvar));
    GetCmdArg(2, value, sizeof(value));

    //make sure quotes are correct
    ReplaceString(cvar, 64, "\"", "", false);
    ReplaceString(value, 64, "\"", "", false);
    ReplaceString(cvar, 64, "\n", "", false);
    ReplaceString(value, 64, "\n", "", false);    

    PrintToServer("Argument %d: %s", 1, cvar);
    PrintToServer("Argument %d: %s", 2, value);

    ConVar hCVar;
    
    if ( (hCVar = FindConVar(cvar))==null ){
        PrintToChat(client, "CVar does not exist.");
        return Plugin_Handled;
    }

    //Activate the cvar value
    SetConVarString(hCVar, value);
    delete hCVar;

    //save cvar to trie, check if exists
    Format(cvar, sizeof(cvar), "\"%s\"", cvar);
    Format(value, sizeof(value), "\"%s\"", value);
    SetTrieString(custom_Cvars, cvar, value, true);

    CVarsChanged = true;
    return Plugin_Handled;
}

public Action CB_CVarServer(int args)
{

    //Get command cvar input
    char cvar[64];
    char value[64];
  
    if (args != 2)
    {
        PrintToServer("Usage: sm_cvar <cvar> <value>");
        return Plugin_Handled;
    }

    GetCmdArg(1, cvar, sizeof(cvar));
    GetCmdArg(2, value, sizeof(value));

    //make sure quotes are correct
    ReplaceString(cvar, 64, "\"", "", false);
    ReplaceString(value, 64, "\"", "", false);

    ReplaceString(cvar, 64, "\n", "", false);
    ReplaceString(value, 64, "\n", "", false);

    PrintToServer("Argument %d: %s", 1, cvar);
    PrintToServer("Argument %d: %s", 2, value);

    ConVar hCVar;
    
    if ( (hCVar = FindConVar(cvar))==null ){
        PrintToServer("CVar does not exist.");
        return Plugin_Handled;
    }
    //Activate the cvar value
    SetConVarString(hCVar, value);
    delete hCVar;

    //save cvar to trie, check if exists
    Format(cvar, sizeof(cvar), "\"%s\"", cvar);
    Format(value, sizeof(value), "\"%s\"", value);
    SetTrieString(custom_Cvars, cvar, value, true);

    CVarsChanged = true;
    return Plugin_Handled;
}

public Action a_getmapcfg(int args){
    GetMapCFG();
    return Plugin_Handled;
}

public Action a_SaveMapCFG(int args){
    SaveMapCFG();
    return Plugin_Handled;
}