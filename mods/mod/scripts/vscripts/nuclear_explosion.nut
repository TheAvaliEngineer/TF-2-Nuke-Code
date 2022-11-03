//		Func decs
global function DoNuclearExplosion

//		Data
//	Nuclear explosion properties
const int NUCLEAR_STRIKE_EXPLOSION_COUNT = 16
const float NUCLEAR_STRIKE_EXPLOSION_TIME = 1.4
const float NUCLEAR_STRIKE_EXPLOSION_DELAY = 2.5

//	Nuclear explosion FX
const asset NUCLEAR_STRIKE_FX_3P = $"P_xo_exp_nuke_3P_alt"
const asset NUCLEAR_STRIKE_FX_1P = $"P_xo_exp_nuke_1P_alt"
const asset NUCLEAR_STRIKE_SUN_FX = $"P_xo_nuke_warn_flare"

const vector NUCLEAR_STRIKE_FX_OFFSET = Vector( 0, 0, -100 )

#if SERVER
void function DoNuclearExplosion( entity projectile, int damageSourceID = 0, float fuseTime = NUCLEAR_STRIKE_EXPLOSION_DELAY,
		int explosionCount = NUCLEAR_STRIKE_EXPLOSION_COUNT, float totalTime = NUCLEAR_STRIKE_EXPLOSION_TIME ) {
	//	Player validity check
	entity player = projectile.GetOwner()
	if( !IsValid(player) ) {
		if( IsValid(projectile) )
			projectile.Destroy()
		return
	}
	int team = player.GetTeam()

	//	damageSourceID validity check
	if( damageSourceID == 0 )
		damageSourceID = projectile.ProjectileGetDamageSourceID()

	/*		Get data from projectile
	 *	While it would make sense to get this info only when it's needed,
	 *	the projectile may move in between now and the end of the fuse
	 *	period. As such, the script gathers that information here.
	 */
	RadiusDamageData r = GetRadiusDamageDataFromProjectile( projectile, player )

	int damage 				= r.explosionDamage
	int damageHeavyArmor 	= r.explosionDamageHeavyArmor
	float innerRadius 		= r.explosionInnerRadius
	float outerRadius 		= r.explosionRadius

	vector origin = projectile.GetOrigin()

	//	Fusing code
	if( fuseTime > 0 ) {
		//	Fuse (S)FX
		entity fx = PlayFXOnEntity( NUCLEAR_STRIKE_SUN_FX, projectile )
		EmitSoundOnEntity( projectile, "titan_nuclear_death_charge" )

		wait fuseTime

		//	Make sure FX is gone
		if ( IsValid( fx ) )
			fx.Destroy()
	}

	//		Explosion (S)FX
	//	Change origin if projectile has moved. Since the explosion only happens
	//	at 1 point, attaching FX to an entity is unnecessary.
	if( IsValid(projectile) )
		origin = projectile.GetOrigin()

	//	FX
	vector angles = Vector(0, RandomInt(360), 0)
	if( IsValid(player) ) {
		//	This is equivalent to the confusing __CreateFxInternal bullshit.
		//	These may need to be threaded.
		PlayFXForPlayer( NUCLEAR_STRIKE_FX_3P, player, origin + NUCLEAR_STRIKE_FX_OFFSET, angles )
		PlayFXForEveryoneExceptPlayer( NUCLEAR_STRIKE_FX_3P, player, origin + NUCLEAR_STRIKE_FX_OFFSET, angles )
	} else {
		PlayFX( NUCLEAR_STRIKE_FX_3P, origin + NUCLEAR_STRIKE_FX_OFFSET, angles )
	}

	//	SFX
	EmitSoundAtPosition( team, origin, "titan_nuclear_death_explode" )

	//		Damage handling
	//	TF|2 requires damage to have an inflictor - this creates one for damaging purposes.
	entity inflictor = CreateEntity( "script_ref" )
	inflictor.SetOrigin( origin )
	inflictor.kv.spawnflags = SF_INFOTARGET_ALWAYS_TRANSMIT_TO_CLIENT

	DispatchSpawn( inflictor )

	//	Kill inflictor & projectile if interrupted
	OnThreadEnd( function() : ( projectile, inflictor ) {
		if( IsValid(projectile) )
			projectile.Destroy()

		if ( IsValid(inflictor) )
			inflictor.Destroy()
	})

	//	Deal damage
	float explosionInterval = totalTime / explosionCount
	for( int i = 0; i < explosionCount; i++ ) {
		RadiusDamage(
			origin,												// origin
			player,												// owner
			inflictor,		 									// inflictor
			damage,												// damage
			damageHeavyArmor,									// heavy armor damage
			innerRadius,										// inner radius
			outerRadius,										// outer radius
			SF_ENVEXPLOSION_NO_NPC_SOUND_EVENT,					// explosion flags
			0, 													// distanceFromAttacker
			0, 													// explosionForce
			0,													// damage flags
			damageSourceID )									// damage source id

		wait explosionInterval
	}
}
#endif
