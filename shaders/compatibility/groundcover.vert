#version 120

#if @useUBO
    #extension GL_ARB_uniform_buffer_object : require
#endif

#if @useGPUShader4
    #extension GL_EXT_gpu_shader4: require
#endif

#include "lib/core/vertex.h.glsl"

#define GROUNDCOVER

attribute vec4 aOffset;
attribute vec3 aRotation;

#if @diffuseMap
varying vec2 diffuseMapUV;
#endif

#if @normalMap
varying vec2 normalMapUV;
#endif

// Other shaders respect forcePPL, but legacy groundcover mods were designed to work with vertex lighting.
// They may do not look as intended with per-pixel lighting, so ignore this setting for now.
#define PER_PIXEL_LIGHTING @normalMap

varying float euclideanDepth;
varying float linearDepth;

#if PER_PIXEL_LIGHTING
varying vec3 passViewPos;
#else
centroid varying vec3 passLighting;
centroid varying vec3 shadowDiffuseLighting;
#endif

varying vec3 passNormal;

#include "shadows_vertex.glsl"
#include "compatibility/normals.glsl"
#include "lib/light/lighting.glsl"
#include "lib/view/depth.glsl"

uniform float osg_SimulationTime;
uniform mat4 osg_ViewMatrixInverse;
uniform mat4 osg_ViewMatrix;
uniform float windSpeed;
uniform vec3 playerPos;

#if @groundcoverStompMode == 0
#else
    #define STOMP 1
    #if @groundcoverStompMode == 2
        #define STOMP_HEIGHT_SENSITIVE 1
    #endif
    #define STOMP_INTENSITY_LEVEL @groundcoverStompIntensity
#endif

// TURBOGRASS 1.1, wind for grass. Grass leans downwind and sways around that lean. Gusts roll across the
// field as fronts of scrolling gradient noise: where one arrives, grass leans further over in well under a
// second, holds there while it lasts, then eases back out over about two seconds. In storms the lean also
// swells and falls with the same noise, so grass never stands straight. Vertices swing around the ground
// point under them instead of sliding sideways, so blades curve and keep their length.
//
// Bend amounts are radians of lean for a blade WIND_REF_HEIGHT units tall; shorter blades bend less,
// taller ones more, easing off towards WIND_MAX_BEND. CALM is windless weather, FULL a blight storm
// (Weather_*_Wind_Speed 0.9; clear is 0.1, rain 0.3, thunderstorm 0.5).
#define WIND_DIRECTION    vec2(-0.53, 0.848) // where the wind blows to; matches the water shader's waves
// Height is measured from the root, WIND_ROOT_DEPTH mesh units below the mesh origin, and nothing below it
// bends. Groundcover mods place the origin above the terrain, with blades reaching down into it to cover
// slopes: the ground is 15-22 units below it in Remiros', 20-25 in Fantasia, 27 in Aesthesia. Rock meshes
// top out 6-8 units below it, so a root deeper than that shifts their tops very slightly.
// A blade's lowest vertex is buried and never moves, so a blade whose next vertex is high up swings around
// that buried end and its base slides along the ground; on slopes some blades also stand on ground above
// the root. Storms bend far enough to show both, so the root rises from rain to a thunderstorm, then on
// with the fury to the mesh origin by a blight storm.
#define WIND_ROOT_DEPTH        10.0
#define WIND_ROOT_DEPTH_STORM  5.0
#define WIND_ROOT_RISE_FROM    0.3  // Weather_*_Wind_Speed where the root starts rising (rain)
#define WIND_ROOT_RISE_TO      0.5  // and where it reaches WIND_ROOT_DEPTH_STORM (thunderstorm)
#define WIND_REF_HEIGHT   67.0
#define WIND_MAX_BEND     1.5
#define WIND_LEAN_CALM    0.04   // steady lean downwind
#define WIND_LEAN_FULL    0.6
#define WIND_SWELL_FULL   0.35   // slow rise and fall of the lean with the gust noise; scales with wind^3, so storms only
#define WIND_GUST_CALM    0.12   // extra lean while a gust passes
#define WIND_GUST_FULL    0.55
#define WIND_SWAY_CALM    0.04   // each clump's slow swing around its lean
#define WIND_SWAY_FULL    0.12
#define WIND_SWAY_FREQ    2.1    // rad/s
#define WIND_NORMAL_TILT  1.0    // how far normals follow the bend; this is what makes gusts read as light

// Storm boost on top of the CALM..FULL blend, so clear weather stays as tuned. It ramps up linearly after
// cloudy/overcast: rain gets a third of it, a thunderstorm and up all of it.
#define WIND_STORM_FROM       0.2   // Weather_*_Wind_Speed where the boost begins
#define WIND_STORM_TO         0.5   // and where it is full
#define WIND_STORM_LEAN       0.35  // extra steady lean
#define WIND_STORM_GUST_START -0.16 // lowers the gust threshold: a thunderstorm is ~78% at full lean, a blight storm ~87%
#define WIND_STORM_SWAY       2.5   // sway multiplier
#define WIND_STORM_SWAY_FREQ  3.6   // rad/s; storms crossfade the sway to this faster rate
#define WIND_STORM_FLUTTER    6.0   // flutter amplitude multiplier

// Fury: past a thunderstorm, up to a blight storm, the grass gets wilder still. The lean is near the bend limit
// by then, so this adds motion rather than more lean (an ashstorm gets 0.75 of it, blight all of it).
#define WIND_FURY_FROM        0.5   // Weather_*_Wind_Speed where fury begins
#define WIND_FURY_TO          0.9   // and where it is full
#define WIND_FURY_SWAY        1.44  // further sway multiplier
#define WIND_FURY_SWAY_FREQ   5.5   // rad/s; fury crossfades the sway to this rate
#define WIND_FURY_FLUTTER     1.8   // further flutter amplitude multiplier
#define WIND_FURY_FLUTTER_FREQ 1.3  // flutter rate multiplier; fury crossfades to copies running this much faster

// Flutter, a quick shiver of single blades. Between gusts its rate drifts slowly up and down in large irregular
// patches, and its amplitude goes the other way, so slow flutter swings wider and fast flutter tighter with the
// tip moving at about the same speed. A gust switches it to a faster rate and its own amplitude.
#define WIND_FLUTTER_CALM       0.0025 // amplitude between gusts at the average rate; 2x at the slowest, 0.66x at the fastest
#define WIND_FLUTTER_FULL       0.006
#define WIND_FLUTTER_FREQ       12.33  // rad/s between gusts, on average
#define WIND_FLUTTER_FREQ_SWING 6.33   // rad/s the rate drifts either way, over tens of seconds (6 to 18.7)
#define WIND_FLUTTER_FREQ_GUST  18.0   // rad/s inside a gust
#define WIND_FLUTTER_GUST_AMP   1.5    // amplitude inside a gust, as a share of between gusts
#define WIND_FLUTTER_FADE_START 2000.0 // game units from the camera where flutter starts fading out; it is under
#define WIND_FLUTTER_FADE_END   3500.0 // a pixel by then, and skipping it there saves most of its cost

// Gust timing. A noise cell is WIND_GUST_LENGTH units along the wind and WIND_GUST_WIDTH across it, so gusts
// arrive as wide fronts. Grass leans in over about 0.65 s and back out over about 2 s. In clear weather about
// 30% of the field is fully leaning at any moment (half of it in some gust), with calm stretches of about 7 s
// at a spot; windless weather has about 15%, a thunderstorm about 50%, a blight storm about 60% with 80% of
// the field in some gust. Speed and heading stay constant on purpose: the scroll offset is speed * time, so
// tying either to the weather would make the whole field jump.
#define WIND_GUST_LENGTH     2000.0
#define WIND_GUST_WIDTH      4000.0
#define WIND_GUST_SPEED      300.0 // units/s the fronts travel downwind
#define WIND_GUST_EVOLVE     0.05  // noise cells/s; how fast fronts change shape as they travel
#define WIND_GUST_START_CALM 0.07  // noise level where a gust begins; the noise is about +-0.45, sd 0.19,
#define WIND_GUST_START_FULL -0.22 // so lower puts more of the field under a gust (0.0 = half of it)
#define WIND_GUST_RAMP_IN    0.08  // noise range over which grass leans in as a gust arrives; smaller = sharper
#define WIND_GUST_RAMP_OUT   0.28  // and over which it leans back out as the gust leaves

// Hash without sine (Dave Hoskins), stays stable at world-coordinate magnitudes
vec3 windHash(vec3 p)
{
    p = fract(p * vec3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx) * 2.0 - 1.0;
}

// 3D gradient (Perlin) noise, about -0.45..0.45 with sd 0.19. Returns the value and its slope along x, which
// costs a few mixes here instead of a second noise lookup
vec2 windNoise(vec3 p)
{
    vec3 i = floor(p);
    vec3 f = fract(p);
    vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float du = 30.0 * f.x * f.x * (f.x * (f.x - 2.0) + 1.0);
    vec2 e = vec2(1.0, 0.0);
    vec3 g000 = windHash(i);
    vec3 g100 = windHash(i + e.xyy);
    vec3 g010 = windHash(i + e.yxy);
    vec3 g110 = windHash(i + e.xxy);
    vec3 g001 = windHash(i + e.yyx);
    vec3 g101 = windHash(i + e.xyx);
    vec3 g011 = windHash(i + e.yxx);
    vec3 g111 = windHash(i + e.xxx);
    float n000 = dot(g000, f);
    float n100 = dot(g100, f - e.xyy);
    float n010 = dot(g010, f - e.yxy);
    float n110 = dot(g110, f - e.xxy);
    float n001 = dot(g001, f - e.yyx);
    float n101 = dot(g101, f - e.xyx);
    float n011 = dot(g011, f - e.yxx);
    float n111 = dot(g111, f - e.xxx);
    float value = mix(mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
        mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y), u.z);
    float slope = du * mix(mix(n100 - n000, n110 - n010, u.y), mix(n101 - n001, n111 - n011, u.y), u.z)
        + mix(mix(mix(g000.x, g100.x, u.x), mix(g010.x, g110.x, u.x), u.y),
            mix(mix(g001.x, g101.x, u.x), mix(g011.x, g111.x, u.x), u.y), u.z);
    return vec2(value, slope);
}

// One sway cycle: along the wind, with a smaller, slower sideways swing
vec2 swayShape(float phase, vec2 dir, vec2 side)
{
    return dir * sin(phase) + side * (0.4 * sin(0.77 * phase + 1.3));
}

// One flutter cycle: mostly along the wind, with a smaller sideways swing a little out of step
vec2 flutterShape(float phase, vec2 dir, vec2 side)
{
    return dir * sin(phase) + side * (0.4 * sin(phase + 1.3));
}

// World-space offset for a vertex h units up its blade, plus the bend so main() can tilt the normal. dist is
// the clump's distance from the camera.
// Per-instance randomness (rnd) and phase offsets (localpos) must come from the chunk-local attributes:
// world positions are rebuilt from float matrices every frame and wobble by ~0.01 units around x=80000,
// which is enough to re-roll a hash each frame and make the grass jitter.
vec3 groundcoverBend(in vec3 worldpos, in vec3 localpos, in vec3 rnd, float h, float dist, out vec2 bendDir,
    out float bendAngle)
{
    vec2 dir = normalize(WIND_DIRECTION);
    vec2 side = vec2(-dir.y, dir.x);
    // sqrt spreads the weathers out: clear 0.32, rain 0.55, thunderstorm 0.71, blight 0.95
    float w = sqrt(clamp(windSpeed, 0.0, 1.0));
    float storm = clamp((windSpeed - WIND_STORM_FROM) / (WIND_STORM_TO - WIND_STORM_FROM), 0.0, 1.0);
    float fury = clamp((windSpeed - WIND_FURY_FROM) / (WIND_FURY_TO - WIND_FURY_FROM), 0.0, 1.0);

    // Gust fronts: noise scrolled downwind and stretched across it, evolving slowly through its third axis
    // so a front changes shape as it travels instead of sliding past like a texture
    vec3 g = vec3(dot(worldpos.xy, dir) / WIND_GUST_LENGTH - osg_SimulationTime * (WIND_GUST_SPEED / WIND_GUST_LENGTH),
        dot(worldpos.xy, side) / WIND_GUST_WIDTH, osg_SimulationTime * WIND_GUST_EVOLVE);
    vec2 gustNoise = windNoise(g);
    float n = gustNoise.x;
    // The slope along the wind tells whether the gust here is arriving (more of it upwind) or leaving, which
    // picks the sharp ramp or the soft one. Blending on the slope keeps the switch at a gust's peak smooth
    float arriving = smoothstep(-0.3, 0.3, -gustNoise.y);
    float start = mix(WIND_GUST_START_CALM, WIND_GUST_START_FULL, w) + WIND_STORM_GUST_START * storm;
    float gustOn = mix(smoothstep(start, start + WIND_GUST_RAMP_OUT, n),
        smoothstep(start, start + WIND_GUST_RAMP_IN, n), arriving);
    // The strongest gusts push a little further still
    float gust = 0.75 * gustOn + 0.25 * smoothstep(start + WIND_GUST_RAMP_IN, start + WIND_GUST_RAMP_OUT, n);
    // Storm swell: the lean follows the same noise continuously, so heavy weather varies it but never lets go
    float swell = smoothstep(-0.35, 0.35, n) * (WIND_SWELL_FULL * w * w * w);

    // Each clump swings at its own phase, its blades slightly out of step with each other
    // (storms crossfade to faster swings; a changing rate can't multiply time, see the flutter below). storm
    // and fury are the same for the whole draw, so skipping their swings in calmer weather costs no divergence
    float swayPh = 6.2832 * rnd.x + dot(localpos.xy, vec2(0.021, 0.017));
    vec2 sway = swayShape(osg_SimulationTime * WIND_SWAY_FREQ + swayPh, dir, side);
    if (storm > 0.0)
        sway = mix(sway, swayShape(osg_SimulationTime * WIND_STORM_SWAY_FREQ + swayPh, dir, side), storm);
    if (fury > 0.0)
        sway = mix(sway, swayShape(osg_SimulationTime * WIND_FURY_SWAY_FREQ + swayPh, dir, side), fury);
    sway *= mix(WIND_SWAY_CALM, WIND_SWAY_FULL, w) * (0.5 + gust) * mix(1.0, WIND_STORM_SWAY, storm)
        * mix(1.0, WIND_FURY_SWAY, fury);

    // Flutter. The phase drifts slowly across the clump so blades a hand apart differ but each blade moves as
    // one piece. A changing rate can't multiply time, that would spin the phase by the whole elapsed time, so:
    // - between gusts the rate is three slow sines at unrelated speeds and headings (patches of 3000-6000 units,
    //   30-80 s cycles), and the phase is their integral, each sin becoming -cos / speed;
    // - a gust crossfades to a second, fixed-rate oscillator;
    // - fury crossfades both to copies running WIND_FURY_FLUTTER_FREQ times faster. Scaling a rate scales its
    //   whole integral, so their phases are just these phases scaled.
    // Far away flutter is under a pixel, so it fades out and is skipped; whole clumps take the same branch.
    vec2 flutter = vec2(0.0);
    float flutterFade = 1.0 - smoothstep(WIND_FLUTTER_FADE_START, WIND_FLUTTER_FADE_END, dist);
    if (flutterFade > 0.0)
    {
        vec3 swellSpeed = vec3(0.21, 0.13, 0.077);
        vec3 swellArg = osg_SimulationTime * swellSpeed + vec3(dot(worldpos.xy, vec2(0.00168, 0.00126)),
            dot(worldpos.xy, vec2(-0.0007, 0.00121)), dot(worldpos.xy, vec2(0.000294, -0.001008)));
        float ph = 6.2832 * rnd.y + dot(localpos, vec3(0.05, 0.06, 0.015));
        float calmPhase = osg_SimulationTime * WIND_FLUTTER_FREQ
            - WIND_FLUTTER_FREQ_SWING * dot(vec3(0.5, 0.3, 0.2) / swellSpeed, cos(swellArg));
        float gustPhase = osg_SimulationTime * WIND_FLUTTER_FREQ_GUST;
        float calmRate = WIND_FLUTTER_FREQ + WIND_FLUTTER_FREQ_SWING * dot(vec3(0.5, 0.3, 0.2), sin(swellArg));
        float flutterAmp = mix(WIND_FLUTTER_CALM, WIND_FLUTTER_FULL, w) * mix(1.0, WIND_STORM_FLUTTER, storm)
            * mix(1.0, WIND_FURY_FLUTTER, fury);
        flutter = mix(flutterShape(calmPhase + ph, dir, side), flutterShape(gustPhase + ph, dir, side), gustOn);
        if (fury > 0.0)
            flutter = mix(flutter, mix(flutterShape(calmPhase * WIND_FURY_FLUTTER_FREQ + ph, dir, side),
                flutterShape(gustPhase * WIND_FURY_FLUTTER_FREQ + ph, dir, side), gustOn), fury);
        flutter *= mix(flutterAmp * (WIND_FLUTTER_FREQ / calmRate), flutterAmp * WIND_FLUTTER_GUST_AMP, gustOn)
            * flutterFade;
    }

    vec2 bend = dir * (mix(WIND_LEAN_CALM, WIND_LEAN_FULL, w) + WIND_STORM_LEAN * storm + swell
            + gust * mix(WIND_GUST_CALM, WIND_GUST_FULL, w))
        + sway + flutter;

#if STOMP
    vec2 away = worldpos.xy - playerPos.xy;
    float d = length(away);
#if STOMP_INTENSITY_LEVEL == 0
    // Gentle intensity
    const float STOMP_RANGE = 50.0; // maximum distance from player that grass is affected by stomping
    const float STOMP_BEND = 0.6; // lean right next to the player, same units as the wind bends
#elif STOMP_INTENSITY_LEVEL == 1
    // Reduced intensity
    const float STOMP_RANGE = 80.0;
    const float STOMP_BEND = 0.9;
#elif STOMP_INTENSITY_LEVEL == 2
    // MGE XE intensity
    const float STOMP_RANGE = 150.0;
    const float STOMP_BEND = 1.2;
#endif
    if (d < STOMP_RANGE && d > 0.0)
    {
        float stomp = STOMP_BEND * (1.0 - d / STOMP_RANGE);
#ifdef STOMP_HEIGHT_SENSITIVE
        stomp *= clamp((worldpos.z - playerPos.z) / max(h, 1.0), 0.0, 1.0);
#endif
        bend += away * (stomp / d);
    }
#endif

    float strength = length(bend);
    bendDir = strength > 0.0001 ? bend / strength : dir;
    // Ease off towards WIND_MAX_BEND instead of stopping at it, so storm gusts keep moving rather than pinning
    float a = strength * h / WIND_REF_HEIGHT;
    const float knee = 0.6 * WIND_MAX_BEND;
    bendAngle = a < knee ? a : WIND_MAX_BEND - (WIND_MAX_BEND - knee) * exp((knee - a) / (WIND_MAX_BEND - knee));
    // Swing around the ground point under the vertex: the offset grows with h^2 so the blade curves,
    // and the tip drops so it keeps its length
    return vec3(bendDir * (h * sin(bendAngle)), h * (cos(bendAngle) - 1.0));
}

mat4 rotation(in vec3 angle)
{
    float sin_x = sin(angle.x);
    float cos_x = cos(angle.x);
    float sin_y = sin(angle.y);
    float cos_y = cos(angle.y);
    float sin_z = sin(angle.z);
    float cos_z = cos(angle.z);

    return mat4(
        cos_z*cos_y+sin_x*sin_y*sin_z, -sin_z*cos_x, cos_z*sin_y+sin_z*sin_x*cos_y, 0.0,
        sin_z*cos_y+cos_z*sin_x*sin_y, cos_z*cos_x, sin_z*sin_y-cos_z*sin_x*cos_y, 0.0,
        -sin_y*cos_x, sin_x, cos_x*cos_y, 0.0,
        0.0, 0.0, 0.0, 1.0);
}

mat3 rotation3(in mat4 rot4)
{
    return mat3(
        rot4[0].xyz,
        rot4[1].xyz,
        rot4[2].xyz);
}

void main(void)
{
    vec3 position = aOffset.xyz;
    float scale = aOffset.w;

    mat4 rotation = rotation(aRotation);
    vec4 displacedVertex = rotation * scale * gl_Vertex;

    displacedVertex = vec4(displacedVertex.xyz + position, 1.0);

    mat4 modelToWorld = osg_ViewMatrixInverse * gl_ModelViewMatrix;
    vec4 worldPos = modelToWorld * displacedVertex;
    // Clumps past the fade distance are hidden below, so they skip the wind
    float clumpDist = length(gl_ModelViewMatrix * vec4(position, 1.0));
    vec2 bendDir = vec2(1.0, 0.0);
    float bendAngle = 0.0;
    float rootDepth = mix(mix(WIND_ROOT_DEPTH, WIND_ROOT_DEPTH_STORM,
            clamp((windSpeed - WIND_ROOT_RISE_FROM) / (WIND_ROOT_RISE_TO - WIND_ROOT_RISE_FROM), 0.0, 1.0)),
        0.0, clamp((windSpeed - WIND_FURY_FROM) / (WIND_FURY_TO - WIND_FURY_FROM), 0.0, 1.0));
    if (clumpDist <= @groundcoverFadeEnd)
        worldPos.xyz += groundcoverBend(worldPos.xyz, displacedVertex.xyz, windHash(position + aRotation * 100.0),
            max(gl_Vertex.z + rootDepth, 0.0) * scale, clumpDist, bendDir, bendAngle);
    vec4 viewPos = osg_ViewMatrix * worldPos;

    gl_ClipVertex = viewPos;
    euclideanDepth = length(viewPos.xyz);

    if (clumpDist > @groundcoverFadeEnd)
        gl_Position = vec4(0.0, 0.0, 0.0, 1.0);
    else
        gl_Position = viewToClip(viewPos);

    linearDepth = getLinearDepth(gl_Position.z, viewPos.z);

    passNormal = rotation3(rotation) * gl_Normal.xyz;
    // Tilt the normal with the bend (chunks are only translated, so this space is world-aligned)
    float tilt = bendAngle * WIND_NORMAL_TILT;
    vec3 bendAxis = vec3(-bendDir.y, bendDir.x, 0.0);
    passNormal = passNormal * cos(tilt) + cross(bendAxis, passNormal) * sin(tilt)
        + bendAxis * (dot(bendAxis, passNormal) * (1.0 - cos(tilt)));
    normalToViewMatrix = gl_NormalMatrix;
#if @normalMap
    normalToViewMatrix *= generateTangentSpace(gl_MultiTexCoord7.xyzw * rotation, passNormal);
#endif

#if (!PER_PIXEL_LIGHTING || @shadows_enabled)
    vec3 viewNormal = normalize(gl_NormalMatrix * passNormal);
#endif

#if @diffuseMap
    diffuseMapUV = (gl_TextureMatrix[@diffuseMapUV] * gl_MultiTexCoord@diffuseMapUV).xy;
#endif

#if @normalMap
    normalMapUV = (gl_TextureMatrix[@normalMapUV] * gl_MultiTexCoord@normalMapUV).xy;
#endif

#if PER_PIXEL_LIGHTING
    passViewPos = viewPos.xyz;
#else
    vec3 diffuseLight, ambientLight, specularLight;
    vec3 unusedShadowSpecular;
    doLighting(viewPos.xyz, viewNormal, gl_FrontMaterial.shininess, diffuseLight, ambientLight, specularLight, shadowDiffuseLighting, unusedShadowSpecular);
    passLighting = diffuseLight + ambientLight;
    clampLightingResult(passLighting);
#endif

#if (@shadows_enabled)
    setupShadowCoords(viewPos, viewNormal);
#endif
}
