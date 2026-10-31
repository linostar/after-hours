class_name WingData
extends Resource
## One wing of the museum (data/wings/wing_NN.tres): its masterpiece, its rooms in order
## (room 0 is where the mime comes in; doors name rooms by index), the par time for the
## third star and the forgery's ghost strokes. Content.validate checks it.

## The wing's masterpiece (a Paintings id; the enum lists Paintings.IDS).
@export_enum("pearl_earring", "great_wave", "grande_jatte", "starry_night", "earthly_delights", "mona_lisa") var painting := "starry_night"
## Room scenes (res:// paths), room 0 first.
@export var rooms: Array[String] = []
## Seconds, for the third star.
@export var par_time := 120.0
## The forgery's ghost strokes, in canvas units (ForgeryCanvas.ghosts).
@export var ghosts: Array[PackedVector2Array] = []
