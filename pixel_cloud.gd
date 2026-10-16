@tool
extends Node2D
class_name Cloud

enum Palette { Day, Night, Spooky, Sunset }

@onready var visual: MeshInstance2D = $visual

@export var seed:float = 0:
  set(value):
    seed = value
    _update_params()

@export var alpha:float = 1.0:
  set(value):
    alpha = value
    _update_params()

@export_range(10, 100) var avg_radius:float = 22.0 :
  set(value):
    avg_radius = value
    _update_params()

@export_range(1, 10) var num_puffs:int = 5 :
  set(value):
    num_puffs = value
    _update_params()

@export var dither:bool = true :
  set(value):
    dither = value
    _update_params()

@export var outline:bool = true:
  set(value):
    outline = value
    _update_params()

@export var palette:Palette = Palette.Day :
  set(value):
    palette = value
    _update_params()


func _ready()->void:
  _update_params()

func _update_params():
  if not visual: return
  visual.set_instance_shader_parameter(&"seed", seed)
  visual.set_instance_shader_parameter(&"alpha", alpha)
  visual.set_instance_shader_parameter(&"puffs", num_puffs)
  visual.set_instance_shader_parameter(&"avg_radius", avg_radius)
  var sm:ShaderMaterial = visual.material
  sm.set_shader_parameter(&'dither', dither)
  sm.set_shader_parameter(&'draw_outline', outline)
  sm.set_shader_parameter(&'palette_idx', palette)
