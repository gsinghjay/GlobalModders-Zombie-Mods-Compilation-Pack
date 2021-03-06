/* Script generated by Pawn Studio */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>

#define PLUGIN	"[Bio] Flare grenades"
#define AUTHOR	"5c0r"
#define VERSION	"1.0"

new const grenade_flare[][] = { "items/nvg_on.wav" }
new const sprite_grenade_trail[] = { "sprites/laserbeam.spr" }
const NADE_TYPE_FLARE = 4444
const PEV_FLARE_COLOR = pev_punchangle
const PEV_NADE_TYPE = pev_flTimeStepSound
const TASK_NADES = 1000
// Flare and flame tasks
#define FLARE_ENTITY args[0]
#define FLARE_DURATION args[1]
#define FLARE_R args[2]
#define FLARE_G args[3]
#define FLARE_B args[4]

new g_trailSpr
new cvar_flaregrenades,cvar_flareduration,cvar_flaresize,cvar_flarecolor
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	// Add your own code here
	cvar_flaregrenades = register_cvar("bio_flare_grenades","1")
	cvar_flareduration = register_cvar("bui_flare_duration", "300")
	cvar_flaresize = register_cvar("bio_flare_size", "30")
	cvar_flarecolor = register_cvar("bio_flare_color", "0")
	register_forward(FM_SetModel, "fw_SetModel")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	RegisterHam(Ham_Think, "grenade", "fw_ThinkGrenade")
	
}
public plugin_precache()
{
	new i 
	for (i = 0; i < sizeof grenade_flare; i++)
	engfunc(EngFunc_PrecacheSound, grenade_flare[i])
	g_trailSpr = engfunc(EngFunc_PrecacheModel, sprite_grenade_trail)
}
public event_round_start()
{
	remove_task(TASK_NADES)
}
public fw_SetModel(entity, const model[])
{
	if (equal(model[7], "w_sm", 4) && get_pcvar_num(cvar_flaregrenades)) // Flare
	{
		// Make the flare color
		static rgb[3]
		switch (get_pcvar_num(cvar_flarecolor))
		{
			case 0: // white
			{
				rgb[0] = 255 // r
				rgb[1] = 255 // g
				rgb[2] = 255 // b
			}
			case 1: // red
			{
				rgb[0] = random_num(50,255) // r
				rgb[1] = 0 // g
				rgb[2] = 0 // b
			}
			case 2: // green
			{
				rgb[0] = 0 // r
				rgb[1] = random_num(50,255) // g
				rgb[2] = 0 // b
			}
			case 3: // blue
			{
				rgb[0] = 0 // r
				rgb[1] = 0 // g
				rgb[2] = random_num(50,255) // b
			}
			case 4: // random (all colors)
			{
				rgb[0] = random_num(50,200) // r
				rgb[1] = random_num(50,200) // g
				rgb[2] = random_num(50,200) // b
			}
			case 5: // random (r,g,b)
			{
				switch (random_num(1, 3))
				{
					case 1: // red
					{
						rgb[0] = random_num(50,255) // r
						rgb[1] = 0 // g
						rgb[2] = 0 // b
					}
					case 2: // green
					{
						rgb[0] = 0 // r
						rgb[1] = random_num(50,255) // g
						rgb[2] = 0 // b
					}
					case 3: // blue
					{
						rgb[0] = 0 // r
						rgb[1] = 0 // g
						rgb[2] = random_num(50,255) // b
					}
				}
			}
		}
		
		// Give it a glow
		fm_set_rendering(entity, kRenderFxGlowShell, rgb[0], rgb[1], rgb[2], kRenderNormal, 16);
		
		// And a colored trail
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW) // TE id
		write_short(entity) // entity
		write_short(g_trailSpr) // sprite
		write_byte(10) // life
		write_byte(10) // width
		write_byte(rgb[0]) // r
		write_byte(rgb[1]) // g
		write_byte(rgb[2]) // b
		write_byte(200) // brightness
		message_end()
		
		// Set grenade type on the thrown grenade entity
		set_pev(entity, PEV_NADE_TYPE, NADE_TYPE_FLARE)
		
		// Set flare color on the thrown grenade entity
		set_pev(entity, PEV_FLARE_COLOR, rgb)
	}
}
// Ham Grenade Think Forward
public fw_ThinkGrenade(entity)
{
	// Invalid entity
	if (!pev_valid(entity)) return FMRES_IGNORED;
	
	// Get damage time of grenade
	static Float:dmgtime
	pev(entity, pev_dmgtime, dmgtime)
	
	// Check if it's time to go off
	if (dmgtime > get_gametime())
		return HAM_IGNORED;
	
	// Check if it's one of our custom nades
	switch (pev(entity, PEV_NADE_TYPE))
	{
		case NADE_TYPE_FLARE: // Flare
		{			
			// Light up when it's stopped on ground
			if ((pev(entity, pev_flags) & FL_ONGROUND) && fm_get_speed(entity) < 10)
			{
				// Flare sound
				engfunc(EngFunc_EmitSound, entity, CHAN_WEAPON, grenade_flare[random_num(0, sizeof grenade_flare - 1)], 1.0, ATTN_NORM, 0, PITCH_NORM)
				
				// Our task params
				static params[5]
				params[0] = entity // entity id
				params[1] = get_pcvar_num(cvar_flareduration)/5 // duration
				
				// Retrieve flare color from entity
				pev(entity, PEV_FLARE_COLOR, params[2]) // params[2] r - params[3] g - params[4] b
				
				// Call our lighting task
				set_task(0.1, "flare_lighting", TASK_NADES, params, sizeof params)
			}
			else
			{
				// Delay the explosion until we hit ground
				set_pev(entity, pev_dmgtime, get_gametime() + 0.5)
				return HAM_IGNORED;
			}
		}
		default: return HAM_IGNORED;
	}
	
	return HAM_SUPERCEDE;
}
// Flare Lighting
public flare_lighting(args[5])
{
	// Unexistant flare entity?
	if (!pev_valid(FLARE_ENTITY))
		return;
	
	// Flare depleted -clean up the mess-
	if (FLARE_DURATION <= 0)
	{
		engfunc(EngFunc_RemoveEntity, FLARE_ENTITY)
		return;
	}
	
	// Get origin
	static Float:originF[3]
	pev(FLARE_ENTITY, pev_origin, originF)
	
	// Lighting
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_DLIGHT) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	write_byte(get_pcvar_num(cvar_flaresize)) // radius
	write_byte(FLARE_R) // r
	write_byte(FLARE_G) // g
	write_byte(FLARE_B) // b
	write_byte(51) //life
	write_byte((FLARE_DURATION < 2) ? 3 : 0) //decay rate
	message_end()
	
	// Sparks
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, originF, 0)
	write_byte(TE_SPARKS) // TE id
	engfunc(EngFunc_WriteCoord, originF[0]) // x
	engfunc(EngFunc_WriteCoord, originF[1]) // y
	engfunc(EngFunc_WriteCoord, originF[2]) // z
	message_end()
	
	// Decrease task cycle counter
	FLARE_DURATION -= 1;
	
	// Keep sending flare messaegs
	set_task(5.0, "flare_lighting", TASK_NADES, args, sizeof args)
}
// Set entity's rendering type (from fakemeta_util)
stock fm_set_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16)
{
	static Float:color[3]
	color[0] = float(r)
	color[1] = float(g)
	color[2] = float(b)
	
	set_pev(entity, pev_renderfx, fx)
	set_pev(entity, pev_rendercolor, color)
	set_pev(entity, pev_rendermode, render)
	set_pev(entity, pev_renderamt, float(amount))
}
stock fm_get_speed(entity)
{
	static Float:velocity[3]
	pev(entity, pev_velocity, velocity)
	
	return floatround(vector_length(velocity));
}

