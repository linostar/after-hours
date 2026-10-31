class_name GuardBrain
extends RefCounted
## A guard's decisions as utility scores: each tick the guard fills a Senses snapshot,
## every intent scores 0..1 from it, and the highest wins (ties go to the earlier
## intent in Intent order, so the same senses always give the same intent).
## Chasing beats searching beats inspecting a fake beats investigating a noise beats
## straightening a tilted frame beats patrolling; a nearer noise scores higher.

enum Intent { PATROL, INVESTIGATE, STRAIGHTEN, INSPECT, SEARCH, CHASE }

## Seconds a chasing guard keeps chasing after it last saw the mime.
const CHASE_MEMORY := 2.0
## How far a noise carries (a guard hears it within this distance).
const HEARING_RANGE := 420.0
const CHASE_SCORE := 1.0
const SEARCH_SCORE := 0.8
const INSPECT_SCORE := 0.6
## A noise at the guard's feet; one at the edge of hearing scores half of it.
const INVESTIGATE_SCORE := 0.5
const STRAIGHTEN_SCORE := 0.4
const PATROL_SCORE := 0.1


## What a guard knows this tick.
class Senses:
	## Its suspicion (Detection), 0..1; full starts a chase.
	var suspicion := 0.0
	var chasing := false
	## Seconds since a chasing guard last saw the mime.
	var lost_sight_for := 0.0
	## Seconds of searching still to do (set when a chase is lost or a fake is found out).
	var search_left := 0.0
	## A noise it heard and has not investigated yet, and how far away it was.
	var noise_heard := false
	var noise_distance := 0.0
	## A tilted frame it saw or reached while investigating.
	var tilted_frame_known := false
	## A hung fake in view that it has not inspected on this pass.
	var fake_in_view := false


## Every intent's score (0..1) for `senses`.
static func scores(senses: Senses) -> Dictionary[Intent, float]:
	var chase := Detection.is_full(senses.suspicion) or (senses.chasing and senses.lost_sight_for < CHASE_MEMORY)
	var hearing := clampf(senses.noise_distance / HEARING_RANGE, 0.0, 1.0)
	return {
		Intent.PATROL: PATROL_SCORE,
		Intent.INVESTIGATE: INVESTIGATE_SCORE * (1.0 - 0.5 * hearing) if senses.noise_heard and hearing < 1.0 else 0.0,
		Intent.STRAIGHTEN: STRAIGHTEN_SCORE if senses.tilted_frame_known else 0.0,
		Intent.INSPECT: INSPECT_SCORE if senses.fake_in_view else 0.0,
		Intent.SEARCH: SEARCH_SCORE if senses.search_left > 0.0 else 0.0,
		Intent.CHASE: CHASE_SCORE if chase else 0.0,
	}


## The winning intent of `intent_scores`: the highest, ties to the earlier Intent.
static func choose(intent_scores: Dictionary[Intent, float]) -> Intent:
	var best := Intent.PATROL
	for intent: Intent in Intent.values():
		if intent_scores.get(intent, 0.0) > intent_scores.get(best, 0.0):
			best = intent
	return best
