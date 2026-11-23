#version 440
// Edge Glow: a voice-reactive glow around the screen edge, modelled on
// Apple Intelligence / Siri. Sizes are in logical pixels.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 uResolution;   // surface size
    float uTime;        // seconds; advances faster while speaking / thinking
    float uLevel;       // smoothed voice level, 0..1
    float uThinking;    // 0..1 while transcribing
    float uReveal;      // 0..1.3 entrance sweep from the bottom edge
    float uPresence;    // overall fade
    float uWidth;       // base glow depth
    float uIntensity;   // overall brightness
    float uFlow;        // colour position around the edge, built up frame by frame
    float uRadius;      // corner radius
    vec4 uC0;
    vec4 uC1;
    vec4 uC2;
    vec4 uC3;
    vec4 uC4;
    vec4 uC5;
};

const float TAU = 6.28318530718;

vec3 palette(float x) {
    // Cyclic blend through six colours.
    float s = fract(x) * 6.0;
    float i = floor(s);
    float f = smoothstep(0.0, 1.0, fract(s));
    vec3 a, b;
    if (i < 1.0)      { a = uC0.rgb; b = uC1.rgb; }
    else if (i < 2.0) { a = uC1.rgb; b = uC2.rgb; }
    else if (i < 3.0) { a = uC2.rgb; b = uC3.rgb; }
    else if (i < 4.0) { a = uC3.rgb; b = uC4.rgb; }
    else if (i < 5.0) { a = uC4.rgb; b = uC5.rgb; }
    else              { a = uC5.rgb; b = uC0.rgb; }
    return mix(a, b, f);
}

void main() {
    vec2 p = qt_TexCoord0 * uResolution;
    vec2 halfSize = uResolution * 0.5;

    // Distance in from the (rounded) screen edge.
    vec2 q = abs(p - halfSize) - (halfSize - vec2(uRadius));
    float sd = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - uRadius;
    float d = max(-sd, 0.0);

    // Early out for the bulk of the screen.
    float reach = uWidth * 4.5;
    if (d > reach) { fragColor = vec4(0.0); return; }

    // Position around the perimeter, 0..1 (0.75 = bottom centre).
    vec2 c = (p - halfSize) / halfSize;
    float a = atan(c.y, c.x) / TAU + 0.5;

    // Colours drift around the edge and wobble so blobs swell and merge.
    float flow = uFlow;
    float wob = 0.035 * sin(a * TAU * 2.0 + uTime * 0.71)
              + 0.025 * sin(a * TAU * 3.0 - uTime * 1.13)
              + 0.015 * sin(a * TAU * 5.0 + uTime * 1.9);
    vec3 col = palette(a + flow + wob);

    // Glow depth breathes unevenly along the edge, and swells with the voice.
    float breathe = 0.72
        + 0.20 * sin(a * TAU * 3.0 + uTime * 1.30)
        + 0.14 * sin(a * TAU * 5.0 - uTime * 0.83 + 1.7)
        + 0.10 * sin(a * TAU * 8.0 + uTime * 2.30 + 0.4);
    float shimmer = mix(1.0, 0.82 + 0.18 * sin(uTime * 5.0 + a * TAU * 2.0), uThinking);
    // While transcribing, hold a steady mid-level glow instead of following the mic.
    float lvl = max(uLevel, 0.45 * uThinking);
    float w = uWidth * breathe * (0.55 + 1.15 * lvl) * shimmer;
    w = max(w, 1.0);

    // Entrance: the glow rolls up both sides from the bottom centre.
    float fromBottom = abs(fract(a - 0.75 + 0.5) - 0.5) * 2.0; // 0 bottom, 1 top
    float reveal = smoothstep(fromBottom, fromBottom + 0.25, uReveal);

    // A smooth minimum of the four edge distances, so the glow rounds off at the
    // corners instead of meeting in a hard diagonal crease.
    float k = max(w * 0.55, 3.0);
    float ds = -k * log(exp(-p.x / k) + exp(-(uResolution.x - p.x) / k)
                      + exp(-p.y / k) + exp(-(uResolution.y - p.y) / k));
    ds = max(ds + k * 0.05, 0.0);

    // Three layers: a crisp rim, a bright band and a wide soft haze.
    float rim  = exp(-d / 1.6);
    float band = exp(-ds / (w * 0.32));
    float haze = exp(-pow(ds / (w * 1.25), 1.4));
    float energy = 0.85 + 0.55 * lvl;
    float glow = (0.85 * rim + 0.55 * band + 0.45 * haze) * energy * uIntensity;

    // A faint white core on the very edge, as on Apple's; the rest stays saturated.
    vec3 rgb = mix(col, vec3(1.0), clamp(rim * 0.14 + band * 0.05 * lvl, 0.0, 1.0));
    float alpha = clamp(glow, 0.0, 1.0) * reveal * uPresence * qt_Opacity;
    fragColor = vec4(rgb * alpha, alpha);
}
