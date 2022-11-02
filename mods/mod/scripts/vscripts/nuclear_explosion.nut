//		Func decs
global function DoNuclearExplosion

//		Vars
//	Nuclear explosion properties
const int NUCLEAR_STRIKE_EXPLOSION_COUNT = 16
const float NUCLEAR_STRIKE_EXPLOSION_TIME = 1.4
const float NUCLEAR_STRIKE_EXPLOSION_DELAY = 2.5

//	Nuclear explosion FX (this needs to be precached)
const var NUCLEAR_STRIKE_FX_3P = $"P_xo_exp_nuke_3P_alt"
const var NUCLEAR_STRIKE_FX_1P = $"P_xo_exp_nuke_1P_alt"
const var NUCLEAR_STRIKE_SUN_FX = $"P_xo_nuke_warn_flare"

#if SERVER
void function DoNuclearExplosion( entity projectile, int damageSourceID = 0, float fuseTime = NUCLEAR_STRIKE_EXPLOSION_DELAY, int explosionCount = NUCLEAR_STRIKE_EXPLOSION_COUNT, float totalTime = NUCLEAR_STRIKE_EXPLOSION_TIME ) 
{
	float explosionInterval = totalTime / explosionCount

	vector origin = projectile.GetOrigin()
	entity player = projectile.GetOwner()
	if( !IsValid( player ) )
	{
		if( IsValid( projectile ) )
			projectile.Destroy()
		return
	}
	if( damageSourceID == 0 )
		damageSourceID = projectile.ProjectileGetDamageSourceID()
	int team = player.GetTeam()

	RadiusDamageData radiusDamage = GetRadiusDamageDataFromProjectile( projectile, player )

	int normalDamage = radiusDamage.explosionDamage
	int titanDamage = radiusDamage.explosionDamageHeavyArmor
	float innerRadius = radiusDamage.explosionInnerRadius
	float outerRadius = radiusDamage.explosionRadius

	// fuse time
	if( fuseTime > 0 )
	{
		// sun blur
		entity fx = PlayFXOnEntity( NUCLEAR_STRIKE_SUN_FX, projectile )
		EmitSoundOnEntity( projectile, "titan_nuclear_death_charge" )

		wait fuseTime
		if ( IsValid( fx ) )
		fx.Destroy()
	}

	// if projectile changed position...
	if( IsValid( projectile ) )
		origin = projectile.GetOrigin()

	// explosion fx
	if( IsValid( player ) ) 
	{
		thread __CreateFxInternal( 
			NUCLEAR_STRIKE_FX_1P, 
			null, 
			"", 
			origin,
			Vector(0, RandomInt(360), 0), 
			C_PLAYFX_SINGLE, 
			null, 
			1, 
			player )
		thread __CreateFxInternal( 
			NUCLEAR_STRIKE_FX_3P, 
			null, 
			"", 
			origin + Vector(0, 0, -100),
			Vector(0, RandomInt(360), 0), 
			C_PLAYFX_SINGLE, 
			null, 
			6, 
			player )
	} else 
	{
		PlayFX( NUCLEAR_STRIKE_FX_3P, origin + Vector(0, 0, -100), Vector(0, RandomInt(360), 0) )
	}

	EmitSoundAtPosition( team, origin, "titan_nuclear_death_explode" )

	// all damage must have an inflictor currently
	entity inflictor = CreateEntity( "script_ref" )
	inflictor.SetOrigin( origin )

	inflictor.kv.spawnflags = SF_INFOTARGET_ALWAYS_TRANSMIT_TO_CLIENT

	DispatchSpawn( inflictor )

	OnThreadEnd( 
		function() : ( projectile, inflictor ) 
		{
			if( IsValid(projectile) )
				projectile.Destroy()

			if ( IsValid(inflictor) )
				inflictor.Destroy()
		}
	)
	
	// following explosions
	for( int i = 0; i < explosionCount; i++ ) 
	{
		RadiusDamage(
			origin,												// origin
			player,												// owner
			inflictor,		 									// inflictor
			normalDamage,										// normal damage
			titanDamage,										// heavy armor damage
			innerRadius,										// inner radius
			outerRadius,										// outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
			0, 													// distanceFromAttacker
			0, 													// explosionForce
			0,													// damage flags
			damageSourceID										// damage source id
		)

		wait explosionInterval
	}
}
#endif