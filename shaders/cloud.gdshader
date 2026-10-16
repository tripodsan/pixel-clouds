shader_type canvas_item;


uniform vec2 rect_size = vec2(128.0, 128.0); // set to your rect's size in pixels

uniform int num_colors = 4; // colors per texture
uniform int num_palettes = 4; // palettes per texture
uniform bool dither = true;

uniform bool draw_outline = true;

uniform int palette_idx = 0;

instance uniform float seed = 1.0;

instance uniform float avg_radius = 30.0;

instance uniform int puffs = 7;

instance uniform float alpha = 1.0;

uniform sampler2D palette: filter_nearest;

float rand(float n) {
    return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

const float bayer[16] = float[](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);

float bayer4(vec2 px) {
    ivec2 p = ivec2(mod(px, 4.0));
    return (bayer[p.y * 4 + p.x] + 0.5) / 16.0; // threshold in 0..1
}

// light from up-left
float _light(vec2 p, vec2 c, float r) {
  vec2 l = vec2(p.x - (c.x - r*0.35), p.y - (c.y - r*0.4));
  return 1.0 - length(l)/(r*1.45);
}

vec2 scene(vec2 p) {
  float R = avg_radius * (0.75 + rand(seed + 100.0)*0.3);
  float cx = 0.5 * rect_size.x;
  float base = rect_size.y - 1.0;
  float span = R * float(puffs) * 0.85;
  float v = 0.0;

  float dy = p.y - base;
  if (dy > 1.0) {
    return vec2(dy, 0.0);
  }
  float d = 1e9;

  // hump-shaped puffs, tallest in the middle
  for (int i = 0; i < puffs; i++) {
      float fi = float(i);

      float phase = rand(seed + fi + 50.0) * TAU;
      float speed = 0.6 + rand(seed + fi + 60.0) * 0.8;

      float t = (fi + 0.5) / float(puffs);
      float r = R*(0.4 + 0.6*sin(PI*t))*(0.8 + rand(seed + fi + 200.0)*0.4);
      // animate
      r = r * (1.0 + 0.06 * sin(TIME * speed + fi + phase));
      vec2 c = vec2(
        cx - span/2.0 + t*span + (rand(seed + fi + 300.0) - 0.5)*R*0.3,
        base - r*(0.45 + rand(seed + fi + 400.0)*0.45)
      );
      v = max(v, _light(p, c, r));
      d = min(d, length(p - c) - r);              // circle SDF, union via min
  }

  // small circles filling the bottom
  for (int i = 0; i <= puffs; i++) {
      vec2 c = vec2(
        cx - span/2.0 + float(i)/float(puffs)*span,
        base - R*0.3
      );
      float r = R*0.6;
      d = min(d, length(p - c) - r);              // circle SDF, union via min
      v = max(v, _light(p, c, r));
  }
  if (d < 0.0 && dy > 0.0) {
    d = 0.0;
  }

  return vec2(d, v);
}

void fragment() {
    vec2 uv = vec2(UV.x, 1.0 - UV.y);

    vec2 px = floor(uv * rect_size) + 0.5;  // pixel center
    uv = px / rect_size;               // snapped UV

    vec2 dv = scene(px);
    float d = dv.x;
    float v = dv.y;

    // darker towards the bottom
    v -= max(0, (uv.y - (0.5 - 3.0))*0.12);

    float t = dither ? bayer4(px) : 0.5;
    float nc = float(num_colors); // num palette colors
    float pidx = (1.0 / float(num_palettes)) * float(palette_idx);
    v *= 3.0;
    float p = (1.0 + floor(t + clamp(v,0.0,1.0) * (nc - 1.0))) / nc;
    vec4 fill_color = vec4(texture(palette, vec2(p, pidx)).rgb, 1.0);
    vec4 outline_color = texture(palette, vec2(0, pidx));

    bool inside  = d < 0.0;
    bool outline = draw_outline && !inside && d < 1.0;
    COLOR = inside ? fill_color : (outline ? outline_color : vec4(0.0));
    COLOR.a = min(COLOR.a, alpha);
}