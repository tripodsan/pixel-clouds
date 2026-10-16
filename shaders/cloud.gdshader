shader_type canvas_item;

// Size of the rect in art pixels.
uniform vec2 rect_size = vec2(256.0, 64.0);

// Palette texture: one row per palette, one column per color.
// Column 0 is the outline color; columns 1..num_colors-1 go from shadow to highlight.
uniform sampler2D palette : filter_nearest;
uniform int num_colors = 4;
uniform int palette_idx = 0;

uniform bool dither = true;
uniform bool draw_outline = true;

// Shading: lighting is mapped to (light - shade_offset) * shade_contrast before banding.
uniform float shade_offset = 0.35;
uniform float shade_contrast = 3.0;

// Animation: puff "breathing", stepped at this frame rate (0 = smooth).
uniform float anim_fps = 8.0;
uniform float anim_amount = 0.06;

instance uniform float seed = 1.0;
instance uniform float avg_radius = 30.0;
instance uniform int puffs = 7;
instance uniform float alpha = 1.0;

// Per-cloud random number; n selects which value, seed selects the cloud.
float rand(float n) {
    return fract(sin(n * 12.9898 + seed * 78.233) * 43758.5453);
}

const float bayer[16] = float[](
     0.0,  8.0,  2.0, 10.0,
    12.0,  4.0, 14.0,  6.0,
     3.0, 11.0,  1.0,  9.0,
    15.0,  7.0, 13.0,  5.0
);

// Ordered-dither threshold in 0..1, anchored to the rect so it moves with the cloud.
float bayer4(vec2 px) {
    ivec2 p = ivec2(mod(px, 4.0));
    return (bayer[p.y * 4 + p.x] + 0.5) / 16.0;
}

// Light from up-left (y points down). Named _light because light() is a Godot processor function.
float _light(vec2 p, vec2 c, float r) {
    vec2 l = p - vec2(c.x - r * 0.35, c.y - r * 0.4);
    return 1.0 - length(l) / (r * 1.45);
}

// Returns (signed distance to the cloud, lighting). Distance is negative inside.
vec2 scene(vec2 p, float time) {
    float R = avg_radius * (0.75 + rand(1000.0) * 0.3);
    float cx = 0.5 * rect_size.x;
    float base = rect_size.y - 1.0;               // flat bottom, one pixel above the rect edge
    float span = R * float(puffs) * 0.85;

    float d = 1e9;
    float v = 0.0;

    // Hump-shaped puffs, tallest in the middle
    for (int i = 0; i < puffs; i++) {
        float fi = float(i);
        float t = (fi + 0.5) / float(puffs);
        float r = R * (0.4 + 0.6 * sin(PI * t)) * (0.8 + rand(fi + 200.0) * 0.4);

        // Breathe: each puff wobbles with its own phase and speed
        float phase = rand(fi + 500.0) * TAU;
        float speed = 0.6 + rand(fi + 600.0) * 0.8;
        r *= 1.0 + anim_amount * sin(time * speed + phase);

        vec2 c = vec2(
            cx - span / 2.0 + t * span + (rand(fi + 300.0) - 0.5) * R * 0.3,
            base - r * (0.45 + rand(fi + 400.0) * 0.45));
        d = min(d, length(p - c) - r);            // circle SDF, union via min
        v = max(v, _light(p, c, r));
    }

    // Small circles filling the bottom
    for (int i = 0; i <= puffs; i++) {
        vec2 c = vec2(cx - span / 2.0 + float(i) / float(puffs) * span, base - R * 0.3);
        float r = R * 0.6;
        d = min(d, length(p - c) - r);
        v = max(v, _light(p, c, r));
    }

    // Flat bottom: intersect with the half-plane above the baseline,
    // so the outline also traces the cut
    d = max(d, p.y - base);

    // Darker within 3 pixels of the flat bottom
    v -= max(0.0, (p.y - (base - 3.0)) * 0.12);

    return vec2(d, v);
}

void fragment() {
    vec2 uv = vec2(UV.x, 1.0 - UV.y);
    vec2 px = floor(uv * rect_size) + 0.5;
    float time = anim_fps > 0.0 ? floor(TIME * anim_fps) / anim_fps : TIME;

    vec2 dv = scene(px, time);
    float d = dv.x;

    // Band the lighting into fill colors 1..num_colors-1, with ordered dithering
    float v = clamp((dv.y - shade_offset) * shade_contrast, 0.0, 1.0);
    float t = dither ? bayer4(px) : 0.5;
    int idx = min(1 + int(floor(v * float(num_colors - 2) + t)), num_colors - 1);

    vec4 fill_color = vec4(texelFetch(palette, ivec2(idx, palette_idx), 0).rgb, 1.0);
    vec4 outline_color = texelFetch(palette, ivec2(0, palette_idx), 0);

    bool inside = d < 0.0;
    bool outline = draw_outline && !inside && d < 1.0;
    COLOR = inside ? fill_color : (outline ? outline_color : vec4(0.0));
    COLOR.a = min(COLOR.a, alpha);
}
