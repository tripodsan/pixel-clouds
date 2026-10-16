extends Node2D

var scn_cloud = preload('res://cloud.scn')

var SKY_COLORS = {
  Cloud.Palette.Day: Color('6cb4ee'),
  Cloud.Palette.Night: Color('1b2340'),
  Cloud.Palette.Sunset: Color('e9875a'),
  Cloud.Palette.Spooky: Color('1b2340'),
}

@onready var sky: ColorRect = $sky
@onready var clouds:Array[Node2D] = [$clouds_d0, $clouds_d1, $clouds_d2]

@export var palette:Cloud.Palette = Cloud.Palette.Day:
  set(value):
    palette = value
    _update_params()

func _ready() -> void:
  _create_clouds()
  _update_params()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
  for i in clouds.size():
    var speed:float = 10.0 + i * 5.0
    for c:Cloud in clouds[i].get_children():
      c.position.x -= speed * delta
      if c.position.x < -50:
        c.queue_free()
        _spawn_cloud(Vector2(700, randi_range(50, 150)))

func _spawn_cloud(p:Vector2):
  var c:Cloud = scn_cloud.instantiate()
  var depth:int = randi_range(0, 2)
  clouds[depth].add_child(c)
  c.seed = randf()
  c.palette = palette
  c.num_puffs = randi_range(4,6)
  #c.alpha = remap(depth, 0, 2, 0.6, 1.0)
  c.position = p

func _create_clouds():
  for i in 15:
    _spawn_cloud(Vector2(randi_range(0, 640), randi_range(50, 150)))

func _update_params():
  if not sky: return
  sky.color = SKY_COLORS[palette]
  for i in clouds.size():
    for c:Cloud in clouds[i].get_children():
      c.palette = palette
