#include "GlobeShared.h"

struct MosaicLook {
    float4 backdrop;
    float4 backdropShade;
    float4 shard;
    float4 grout;
    float4 groutNight;
    float4 cobalt;
    float4 turquoise;
    float4 seaWhite;
    float4 ochre;
    float4 orange;
    float4 olive;
    float4 lemon;
    float4 gold;
    float4 terracottaBack;
    float4 nightGlaze;
    float4 cityLight;
    float4 twilight;
    float tileSize;
    float tileTilt;
    float glazeGloss;
    float glazeSpec;
    float groutWidth;
    float coastRow;
    float goldChance;
    float goldGloss;
    float flipTime;
    float flipJitter;
    float funnel;
    float pressDepth;
    float recovery;
    float flipThreshold;
    float flipSpread;
    float rattle;
    float inflateSpan;
    float terminatorWidth;
    float cityGlow;
    float patternSize;
    float patternTurns;
    float patternGrout;
    float vignette;
    float seaHeight;
    float landHeight;
    float heightJitter;
    float landShare;
    float bevel;
    float bevelSlope;
    float skirt;
    float flipLift;
    float glazeLine;
    float wallShade;
    float shadeHeight;
    float groutShade;
    float lightsLevel;
    float cutWidth;
    float cutShade;
    float reserved1;
    float reserved2;
};

struct MosaicTile {
    float4 site;
    float4 outline[4];
    float4 inset[4];
    float4 land;
    float4 sea;
    float4 form;
    float4 pose;
    float4 timing;
    float4 motion;
    float4 shake;
};

struct MosaicTileIn {
    float4 position [[position]];
    float3 worldPosition;
    float3 rest;
    float body;
    float4 land [[flat]];
    float4 sea [[flat]];
    float4 anchor [[flat]];
};

constant uint mosaicCorners = 7;
constant float mosaicLeanLimit = 0.45;

static float2 mosaicCorner(float4 pair, uint corner) {
    return (corner & 1u) != 0u ? pair.zw : pair.xy;
}

static float4 mosaicSpin(float2 tip, float angle) {
    float size = length(tip);
    if (size < 1e-6) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }
    return float4(float3(-tip.y, tip.x, 0.0) * (sin(angle * 0.5) / size), cos(angle * 0.5));
}

static float4 mosaicChain(float4 after, float4 before) {
    return float4(after.w * before.xyz + before.w * after.xyz + cross(after.xyz, before.xyz), after.w * before.w - dot(after.xyz, before.xyz));
}

static float3 mosaicRotate(float4 spin, float3 v) {
    float3 twist = 2.0 * cross(spin.xyz, v);
    return v + spin.w * twist + cross(spin.xyz, twist);
}

static float2 mosaicToward(float3 center, float3 target, SurfaceFrame frame) {
    float3 toward = target - center * dot(center, target);
    return float2(dot(toward, frame.east), dot(toward, frame.north));
}

vertex MosaicTileIn mosaicTileVertex(uint vertexID [[vertex_id]],
                                     uint instanceID [[instance_id]],
                                     constant GlobeUniforms &uniforms [[buffer(0)]],
                                     const device MosaicTile *tiles [[buffer(1)]],
                                     constant EffectUniforms &effects [[buffer(2)]],
                                     constant SurfaceUniforms &surface [[buffer(3)]],
                                     const device uint *visible [[buffer(4)]],
                                     texture2d<float> snowTexture [[texture(4)]],
                                     sampler surfaceSampler [[sampler(0)]]) {
    const device MosaicTile &tile = tiles[visible[instanceID]];
    bool bevelled = surface.clock.y > 0.5;
    uint ring = vertexID / mosaicCorners;
    uint corner = vertexID - ring * mosaicCorners;
    uint base = bevelled ? 2u : 1u;
    float height = tile.site.w;
    float2 edge = mosaicCorner(tile.outline[corner >> 1], corner);
    float3 local = float3(edge, 0.0);
    if (ring == 0u) {
        local = float3(bevelled ? mosaicCorner(tile.inset[corner >> 1], corner) : edge, height);
    } else if (ring < base) {
        local.z = height - tile.form.y;
    }

    float3 center = normalize(tile.site.xyz);
    SurfaceFrame frame = surfaceFrame(center);
    float2 lean = tile.pose.xy;
    float2 tip = tile.pose.zw;
    float4 spin = float4(0.0, 0.0, 0.0, 1.0);
    float hop = 0.0;
    if (effectsActive(effects)) {
        if (effects.ripple.w >= 0.0) {
            float arrival = acos(clamp(dot(center, effects.ripple.xyz), -1.0, 1.0)) / max(effects.wave.w, 1e-3) + tile.timing.x;
            if (arrival + tile.timing.y <= tile.motion.w) {
                float progress = saturate((effects.ripple.w - arrival) / tile.timing.y);
                float turn = 2.0 * M_PI_F * smoothstep(0.0, 1.0, progress);
                float2 away = -mosaicToward(center, effects.ripple.xyz, frame);
                spin = mosaicChain(mosaicSpin(length(away) > 1e-5 ? away : tip, turn), spin);
                hop = sin(0.5 * turn);
            }
        }
        float clock = effects.state.w;
        if (clock > 0.0) {
            float2 uv = float2(atan2(center.x, center.z) / (2.0 * M_PI_F) + 0.5, 0.5 - asin(clamp(center.y, -1.0, 1.0)) / M_PI_F);
            float since = clock - snowTexture.sample(surfaceSampler, uv, level(0.0)).r;
            float turn = M_PI_F * (1.0 - smoothstep(tile.timing.z - tile.timing.w, tile.timing.z + tile.timing.w, since));
            spin = mosaicChain(mosaicSpin(tip, turn), spin);
        }
        float3 eye = normalize(uniforms.cameraPosition.xyz);
        float facing = acos(clamp(dot(center, eye), -1.0, 1.0));
        float assemble = M_PI_F * (1.0 - smoothstep(facing, facing + 0.3, tile.motion.x * effects.radii.w));
        float2 inward = mosaicToward(center, eye, frame);
        spin = mosaicChain(mosaicSpin(length(inward) > 1e-5 ? inward : tip, assemble), spin);

        float press = saturate(effects.dent.w / max(tile.motion.z, 1e-5));
        float2 funnel = mosaicToward(center, effects.dent.xyz, frame);
        float funnelLength = length(funnel);
        if (press > 0.0 && funnelLength > 1e-5) {
            lean += funnel * (tile.motion.y * effectWeight(center, effects.dent.xyz, effects.radii.x) * press / funnelLength);
        }
        float stretch = abs(effects.shapeX.x - 1.0) + abs(effects.shapeY.y - 1.0) + abs(effects.shapeZ.z - 1.0);
        lean += tile.shake.xy * stretch;
        float leanLength = length(lean);
        if (leanLength > mosaicLeanLimit) {
            lean *= mosaicLeanLimit / leanLength;
        }
    }

    float3 flipUp = mosaicRotate(spin, float3(0.0, 0.0, 1.0));
    float swing = tile.form.x + tile.shake.z;
    float middle = 0.5 * height;
    float lift = max(swing * sqrt(saturate(1.0 - flipUp.z * flipUp.z)) + middle * (abs(flipUp.z) - 1.0), swing * hop);
    float settle = flipUp.z > 0.0 ? 1.0 - saturate(lift / max(tile.form.z, 1e-5)) : 0.0;
    float4 whole = mosaicChain(spin, mosaicSpin(lean, length(lean)));
    float3 pivot = float3(0.0, 0.0, middle);
    float3 placed = pivot + float3(0.0, 0.0, lift) + mosaicRotate(whole, local - pivot);
    if (ring >= base) {
        float bed = -0.5 * dot(placed.xy, placed.xy) - tile.form.z;
        placed.z = mix(placed.z, min(placed.z, bed), settle);
    }
    float3 world = surfacePlace(center * (1.0 + placed.z) + frame.east * placed.x + frame.north * placed.y, effects);

    MosaicTileIn out;
    out.position = projectToClip(world, uniforms);
    out.worldPosition = world;
    out.rest = center + frame.east * local.x + frame.north * local.y;
    out.body = local.z;
    out.land = tile.land;
    out.sea = tile.sea;
    out.anchor = float4(center, settle);
    return out;
}

fragment half4 mosaicTileFragment(MosaicTileIn in [[stage_in]],
                                  constant GlobeUniforms &uniforms [[buffer(0)]],
                                  constant MosaicLook &look [[buffer(1)]],
                                  constant EffectUniforms &effects [[buffer(2)]],
                                  texture2d<float> lightsTexture [[texture(1)]],
                                  texture2d<float> coastTexture [[texture(2)]],
                                  sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 face = cross(dfdy(in.worldPosition), dfdx(in.worldPosition));
    float bodyWidth = max(fwidth(in.body), 1e-5);
    SurfaceCoordinates coordinates = surfaceCoordinates(normalize(in.rest));
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = max(fwidth(coast), 1e-4);
    bool shaped = effectsActive(effects);
    float3 position = shaped ? effectUnshape(effects) * in.worldPosition : in.worldPosition;
    float3 nG = normalize(position);
    float3 sun = uniforms.sunDirection.xyz;
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    float3 view = normalize(uniforms.cameraPosition.xyz - in.worldPosition);
    float faceLength = length(face);
    float3 normal = faceLength > 1e-12 ? face / faceLength : nG;
    normal = dot(normal, view) < 0.0 ? -normal : normal;

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float warmth = (1.0 - smoothstep(0.0, look.terminatorWidth * 5.0, muG)) * daylight;
    float3 halfway = normalize(sun + view);

    float shade = in.sea.w;
    float tone = 0.92 + 0.16 * shade;
    float land = coastCoverage(coast, coastWidth);
    float rim = coastCoverage(coast + look.coastRow, coastWidth);
    float outerRim = coastCoverage(coast + 2.0 * look.coastRow, coastWidth);
    float3 glaze = mix(in.sea.xyz, mix(look.seaWhite.xyz, look.turquoise.xyz, 0.18) * tone, outerRim);
    glaze = mix(glaze, look.seaWhite.xyz * tone, rim);
    glaze = mix(glaze, in.land.xyz, land);
    float boundary = min(abs(coast), min(abs(coast + look.coastRow), abs(coast + 2.0 * look.coastRow)));
    float cutHalf = look.cutWidth * 0.5;
    float cut = 1.0 - smoothstep(cutHalf - coastWidth * 0.5, cutHalf + coastWidth * 0.5, boundary);

    bool gold = in.land.w * land > 0.5;
    float glazed = smoothstep(look.glazeLine - bodyWidth, look.glazeLine + bodyWidth, in.body);
    float3 albedo = mix(look.terracottaBack.xyz * (0.9 + 0.2 * shade), glaze, glazed);
    float rise = dot(normal, nG);
    float wall = 1.0 - smoothstep(0.35, 0.7, abs(rise));
    float occlusion = mix(1.0, mix(look.wallShade, 1.0, smoothstep(0.0, look.shadeHeight, in.body)), wall * in.anchor.w);

    float lambert = saturate(dot(normal, sun));
    float gloss = gold ? look.goldGloss : look.glazeGloss;
    float specular = pow(saturate(dot(normal, halfway)), gloss) * look.glazeSpec * saturate(muG * 6.0) * glazed;
    float3 specularColor = gold ? look.gold.xyz * 2.2 : float3(1.0);
    float3 day = albedo * (0.16 + 0.84 * lambert) * occlusion + specularColor * specular;
    float3 night = (look.nightGlaze.xyz * (0.7 + 0.3 * shade) + albedo * 0.025) * occlusion;
    float3 color = mix(night, day, daylight);
    color = mix(color, color * look.twilight.xyz * 1.6, warmth * 0.4);

    if (land > 0.0 && nightGate > 0.0) {
        float2 uv = float2(atan2(in.anchor.x, in.anchor.z) / (2.0 * M_PI_F) + 0.5, 0.5 - asin(clamp(in.anchor.y, -1.0, 1.0)) / M_PI_F);
        float lights = lightsTexture.sample(surfaceSampler, uv, level(look.lightsLevel)).r;
        float glow = look.cityGlow * (gold ? 1.0 : 0.25);
        color += look.cityLight.xyz * lights * glow * nightGate * land * glazed * smoothstep(0.5, 0.8, rise);
    }
    color *= mix(1.0, look.cutShade, cut * glazed);

    if (shaped) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 mosaicFragment(MeshFragmentIn in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant MosaicLook &look [[buffer(1)]],
                              constant EffectUniforms &effects [[buffer(2)]]) {
    float2 pixel = in.position.xy;
    float3 nG = normalize(in.spherePosition);
    float3 sun = uniforms.sunDirection.xyz;
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    bool active = effectsActive(effects);
    float3 normal = nG;
    if (active) {
        float3 slope;
        effectOffset(nG, effects, slope);
        normal = normalize(nG - slope);
    }

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float warmth = (1.0 - smoothstep(0.0, look.terminatorWidth * 5.0, muG)) * daylight;
    float3 day = look.grout.xyz * (0.16 + 0.84 * saturate(dot(normal, sun))) * look.groutShade;
    float3 color = mix(look.groutNight.xyz, day, daylight);
    color = mix(color, color * look.twilight.xyz * 1.6, warmth * 0.4);

    if (active) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 mosaicBackground(FullscreenVertex in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant MosaicLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 base = mix(look.backdrop.xyz, look.backdropShade.xyz, smoothstep(0.1, 0.9, length(screen)) * look.vignette * 2.0);

    float3 eye = uniforms.cameraPosition.xyz;
    float eyeDistance = length(eye);
    float pointScale = uniforms.viewport.x / 402.0;
    float cell = look.patternSize * pointScale * pow(3.85 / max(eyeDistance, 1.0), 0.2);
    float yaw = atan2(eye.x, eye.z);
    float pitch = asin(clamp(eye.y / max(eyeDistance, 1e-4), -1.0, 1.0));
    float2 drifted = pixel + float2(-yaw, pitch) * cell * look.patternTurns / M_PI_F;
    float2 motif = drifted / cell;
    float footprint = fwidth(motif.x);

    Cellular tile = cellular(motif, 3.0);
    float3 random = hash33(float3(tile.cell, 5.0));
    float3 tileColor = base * (0.84 + 0.24 * random.x);
    tileColor = mix(tileColor, look.ochre.xyz * 0.62, step(0.9, random.y) * 0.55);
    tileColor = mix(tileColor, look.shard.xyz * 0.78, step(0.985, random.z) * 0.35);
    float bevel = smoothstep(0.0, 0.22, tile.edge);
    float3 shadeAxis = hash33(float3(tile.cell, 9.0)) - 0.5;
    tileColor *= mix(0.86, 1.0, bevel) * (1.0 + 0.08 * shadeAxis.x);
    float glint = pow(saturate(1.0 - tile.edge * 3.5), 3.0) * step(0.5, shadeAxis.y) * 0.08;
    tileColor += look.shard.xyz * glint;

    float grout = 1.0 - smoothstep(look.patternGrout - footprint, look.patternGrout + footprint, tile.edge);
    float3 groutColor = mix(base, look.grout.xyz, 0.32) * 0.9;
    float3 pattern = mix(tileColor, groutColor, grout);

    float open = smoothstep(1.02, 1.3, reach);
    float3 color = mix(base, pattern, mix(0.55, 1.0, open));
    color = mix(color, base * 0.92, 0.35 * exp(-max(reach - 1.0, 0.0) * 6.0));
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
