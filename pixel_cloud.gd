@tool
extends Node2D

enum Palette { Day, Sunset, Night, Gameboy }

var _palettes = {
    Palette.Day: {'sky': "#6cb4ee", 'o': "#3d6e9e", 's': "#a9c4de", 'm': "#dbe8f4", 'h': "#ffffff"},
    Palette.Sunset: {'sky': "#e9875a", 'o': "#7a3b4f", 's': "#c46a7a", 'm': "#f2a99a", 'h': "#ffe3c4"},
    Palette.Night:    {'sky': "#1b2340", 'o': "#0d1226", 's': "#3b4670", 'm': "#5d6b9c", 'h': "#9aa8d4"},
    Palette.Gameboy: {'sky': "#8bac0f", 'o': "#0f380f", 's': "#306230", 'm': "#8bac0f", 'h': "#9bbc0f"}
}

const BAYER = [[0,8,2,10],[12,4,14,6],[3,11,1,9],[15,7,13,5]]

@onready var visual = $visual
@onready var visual_2: MeshInstance2D = $visual2

@export_tool_button('Generate') var btn_generate = generate

@export_range(10, 100) var avg_radius:float = 30.0
@export_range(1, 20) var num_puffs:int = 5
@export var dither:bool = false
@export var outline:bool = false
@export var debug_circles:bool = false
@export var palette:Palette = Palette.Day

class Info extends RefCounted:
  var circles:PackedVector3Array = []
  var base:float

const H = 256
const W = 256

func _create_cloud():
  var R = avg_radius*(0.85 + randf()*0.3)
  var cx = W * 0.5
  var base = H * 0.75
  var span = R * num_puffs * 0.75
  var info = Info.new()
  # hump-shaped puffs, tallest in the middle
  for i in range(num_puffs):
    var t = (i + 0.5)/num_puffs
    var r = R*(0.45 + 0.6*sin(PI*t))*(0.8 + randf()*0.4)
    info.circles.append(Vector3(
      cx - span/2 + t*span + (randf() - 0.5)*R*0.3,
      base - r*(0.35 + randf()*0.35),
      r
    ))

  # small circles filling the bottom
  for i in range(num_puffs + 1):
    info.circles.append(Vector3(
      cx - span/2.0 + i/ float(num_puffs)*span,
      base - R*0.3,
      R*0.4
    ))
  info.base = base
  return info


func generate():
  var grid:PackedByteArray = []
  grid.resize(W * H)
  grid.fill(-1)

  var info = _create_cloud()
  for y in H:
    for x in W:
      var X = x + 0.5
      var Y = y + 0.5
      if Y > info.base:
        # flat bottom
        continue;
      var inside = false
      var v = -9
      for c:Vector3 in info.circles:
        var dx = X - c.x
        var dy = Y - c.y
        if dx*dx + dy*dy < c.z*c.z:
          inside = true
        # light from up-left
        var lx = X - (c.x - c.z*0.35)
        var ly = Y - (c.y - c.z*0.4)
        v = max(v, 1 - sqrt(lx*lx + ly*ly)/(c.z*1.25))

      if !inside:
        continue
      # darker near the bottom
      v -= max(0, (Y - (info.base - 3))*0.12)
      if dither:
        v += (BAYER[y%4][x%4]/16 - 0.47)*0.18
      grid[y*W + x] = 0 if v < 0.18 else (1 if v < 0.42 else 2)

  # create image
  var img:Image = Image.create(W, H, false, Image.Format.FORMAT_RGBA8)
  var pal = _palettes[palette]
  var bands = [Color(pal.s), Color(pal.m), Color(pal.h)]
  for y in H:
    for x in W:
      var g = grid[y*W + x];
      if g != 255:
        img.set_pixel(x, y, bands[g])
        continue
      #var edge = outline && [[1,0],[-1,0],[0,1],[0,-1]].some(([a, b]) => {
        #const xx = x + a, yy = y + b; return xx >= 0 && yy >= 0 && xx < W && yy < H && grid[yy*W + xx] >= 0; });
      #put(x, y, edge ? out : sky);
  visual.texture = ImageTexture.create_from_image(img)

var speed:float = 10.0;

func _ready()->void:
  speed = randf_range(5, 20)
  visual_2.set_instance_shader_parameter(&"seed", randf())
  visual_2.set_instance_shader_parameter(&"puffs", randi_range(3, 7))
  #visual_2.set_instance_shader_parameter(&"alpha", speed / 20.0)

func _process(delta: float) -> void:
  if Engine.is_editor_hint(): return
  position.x -= delta * speed;
  if position.x < -50:
    position.x = 700
