class_name Stars
extends RefCounted
## A finished wing's three stars, each its own icon: the swap done (every escape with the
## original earns it), never seen (no guard's suspicion ever rose), under par time.

enum Star { SWAP, UNSEEN, PAR }


## The stars of an escape after `time` seconds against `par`, in Star order.
static func earned(ever_seen: bool, time: float, par: float) -> Array[bool]:
	return [true, not ever_seen, time <= par]


static func count(stars: Array[bool]) -> int:
	return stars.count(true)
