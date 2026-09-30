#include "GlobeShared.h"

struct SakuraLook {
    float4 backdrop;
    float4 blush;
    float4 haze;
    float4 seaDeep;
    float4 seaOpen;
    float4 seaShallow;
    float4 seaShore;
    float4 seaNight;
    float4 landCoast;
    float4 landLow;
    float4 landHigh;
    float4 landCrest;
    float4 landShade;
    float4 landNight;
    float4 petalLight;
    float4 petalDeep;
    float4 blossomEye;
    float4 pollen;
    float4 raft;
    float4 dusk;
    float4 glow;
    float4 cityLight;
    float4 glint;
    float4 nightHaze;
    float4 patternInk;
    float wrap;
    float shallowWidth;
    float shoreWidth;
    float clumpScale;
    float clumpDepth;
    float blossomSize;
    float blossomDensity;
    float budSize;
    float budDensity;
    float raftSize;
    float raftWidth;
    float raftDensity;
    float transmission;
    float twilightWidth;
    float haziness;
    float glintPower;
    float glintStrength;
    float nightLift;
    float cityGlow;
    float sheen;
    float petalTranslucency;
    float mist;
    float drift;
    float driftSize;
    float patternSize;
    float patternStrength;
    float patternTurns;
    float grain;
};

struct SakuraBloom {
    float coverage;
    float depth;
    float eye;
    float tint;
};

struct SakuraCell {
    float2 offset;
    float3 random;
    float3 shape;
    float present;
};

static float sakuraNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float lowerNear = mix(hash33(cell).x, hash33(cell + float3(1.0, 0.0, 0.0)).x, t.x);
    float lowerFar = mix(hash33(cell + float3(0.0, 1.0, 0.0)).x, hash33(cell + float3(1.0, 1.0, 0.0)).x, t.x);
    float upperNear = mix(hash33(cell + float3(0.0, 0.0, 1.0)).x, hash33(cell + float3(1.0, 0.0, 1.0)).x, t.x);
    float upperFar = mix(hash33(cell + float3(0.0, 1.0, 1.0)).x, hash33(cell + float3(1.0, 1.0, 1.0)).x, t.x);
    return mix(mix(lowerNear, lowerFar, t.y), mix(upperNear, upperFar, t.y), t.z);
}

static float sakuraPetalShape(float2 p) {
    float t = saturate(p.x * 0.5 + 0.5);
    float width = mix(0.2, 0.82, sqrt(t));
    float body = (length(float2((p.x - 0.06) / 0.94, p.y / width)) - 1.0) * min(width, 0.94);
    float notch = ((p.x - 0.74) - abs(p.y) * 1.9) * 0.46;
    return max(body, notch);
}

static float sakuraSeigaiha(float2 p, float halfWidth, float feather) {
    float top = ceil(2.0 * (p.y + 1.0)) - 1.0;
    for (int k = 0; k < 4; k++) {
        float row = top - float(k);
        float offset = row - 2.0 * floor(row * 0.5);
        float2 center = float2(2.0 * round((p.x - offset) * 0.5) + offset, row * 0.5);
        float distance = length(p - center);
        if (distance < 1.0) {
            float ring = abs(fract(distance * 4.0 + 0.5) - 0.5) * 0.25;
            float edge = min(ring, 1.0 - distance);
            return 1.0 - smoothstep(halfWidth - feather, halfWidth + feather, edge);
        }
    }
    return 0.0;
}

static SakuraCell sakuraCell(float2 uv, float cosLatitude, float cell, float seed, float spread) {
    float latitude = (0.5 - uv.y) * 180.0;
    float band = (latitude + 90.0) / cell;
    float row = floor(band);
    float rowLatitude = (row + 0.5) * cell - 90.0;
    float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / cell), 1.0);
    float along = fract(uv.x) * columns;
    float column = floor(along);
    SakuraCell result;
    result.random = hash33(float3(column, row, seed));
    result.shape = hash33(float3(row + 0.5, column + 0.5, seed + 3.0));
    float2 spot = 0.5 - spread * 0.5 + spread * result.random.yz;
    float cellWidth = 360.0 * cosLatitude / columns;
    result.offset = float2((fract(along) - spot.x) * cellWidth, (band - row - spot.y) * cell);
    result.present = 1.0;
    return result;
}

static SakuraBloom sakuraBloom(float2 uv, float cosLatitude, float size, float density, float seed, float footprint) {
    SakuraBloom bloom = {0.0, 0.0, 0.0, 0.0};
    SakuraCell cell = sakuraCell(uv, cosLatitude, size * 3.2, seed, 0.2);
    if (cell.random.x > density) {
        return bloom;
    }
    float radius = size * mix(0.75, 1.15, cell.shape.x);
    float pixel = max(footprint / radius, 1e-4);
    float r = length(cell.offset) / radius;
    if (r > 1.1 + pixel) {
        return bloom;
    }
    float angle = atan2(cell.offset.y, cell.offset.x) + cell.shape.y * 6.2831853;
    float sector = 2.0 * M_PI_F / 5.0;
    float a = angle - sector * round(angle / sector);
    float2 local = float2(r * cos(a) * 2.0 - 1.0, r * sin(a) * 2.6);
    float petal = sakuraPetalShape(local) * 0.5;
    bloom.coverage = saturate(0.5 - petal / pixel);
    bloom.depth = saturate(1.0 - r);
    bloom.eye = saturate(0.5 - (r - 0.15) / pixel) * (1.0 - smoothstep(0.07, 0.16, pixel));
    bloom.tint = cell.shape.z;
    return bloom;
}

static float sakuraRaftPetal(float2 uv, float cosLatitude, float size, float density, float seed, float footprint, thread float &tint) {
    SakuraCell cell = sakuraCell(uv, cosLatitude, size * 3.0, seed, 0.3);
    if (cell.random.x > density) {
        return 0.0;
    }
    float extent = size * mix(0.7, 1.0, cell.shape.x);
    float pixel = max(footprint / extent, 1e-4);
    float angle = cell.shape.y * 6.2831853;
    float2 axis = float2(cos(angle), sin(angle));
    float2 local = float2(dot(cell.offset, axis), dot(cell.offset, float2(-axis.y, axis.x))) / extent;
    tint = cell.shape.z;
    return saturate(0.5 - sakuraPetalShape(local) / pixel);
}

fragment half4 sakuraFragment(MeshFragmentIn in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant SakuraLook &look [[buffer(1)]],
                              constant EffectUniforms &effects [[buffer(2)]],
                              texture2d<float> lightsTexture [[texture(1)]],
                              texture2d<float> coastTexture [[texture(2)]],
                              texture2d<float> reliefTexture [[texture(3)]],
                              sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), 0.012);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d haloGradient = gradient2d(coordinates.dx * 6.0, coordinates.dy * 6.0);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float lightsHalo = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nMap = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coastWidth = max(fwidth(coast), 1e-4);
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float land = 1.0 - water;
    float3 nM = normalize(mix(nMap, nG, water));
    float relief = saturate(normalHeight.w);
    float cosLatitude = max(length(nG.xz), 1e-3);
    float2 degrees = float2(360.0 * cosLatitude, 180.0);
    float footprint = max(max(length(coordinates.dx * degrees), length(coordinates.dy * degrees)), 1e-5);
    float dayGate = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.1736, 0.0175, muG);

    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope - water * effects.wave.x * rippleSlope(nG, effects));
        relief *= effects.radii.w;
    }

    float height = smoothstep(0.0, 0.9, relief);
    float clumpCell = 57.2958 / look.clumpScale;
    float clumpNear = 1.0 - smoothstep(0.2, 0.55, footprint / clumpCell);
    float clumpFine = 1.0 - smoothstep(0.2, 0.55, footprint * 2.3 / clumpCell);
    float clump = 0.5;
    SakuraBloom bloom = {0.0, 0.0, 0.0, 0.0};
    SakuraBloom bud = {0.0, 0.0, 0.0, 0.0};
    float bloomDetail = 0.0;
    float budDetail = 0.0;
    if (land > 0.0) {
        clump = 0.5 + (sakuraNoise(nG * look.clumpScale) - 0.5) * clumpNear * 0.7
                    + (sakuraNoise(nG * look.clumpScale * 2.3 + 11.0) - 0.5) * clumpFine * 0.45;
        bloomDetail = 1.0 - smoothstep(0.3, 0.75, footprint / look.blossomSize);
        budDetail = 1.0 - smoothstep(0.3, 0.75, footprint / look.budSize);
        if (bloomDetail > 0.0) {
            bloom = sakuraBloom(coordinates.uv, cosLatitude, look.blossomSize, look.blossomDensity, 5.0, footprint);
        }
        if (budDetail > 0.0) {
            bud = sakuraBloom(coordinates.uv, cosLatitude, look.budSize, look.budDensity, 13.0, footprint);
        }
    }

    float variety = sakuraNoise(nG * 7.0 + 5.0) * 0.65 + sakuraNoise(nG * 17.0 + 9.0) * 0.35;
    float3 canopy = mix(look.landCoast.xyz, look.landLow.xyz, smoothstep(0.0, 0.9, coast));
    canopy = mix(canopy, mix(look.petalDeep.xyz, look.landCrest.xyz, smoothstep(0.35, 0.65, variety)), 0.3 * land);
    canopy = mix(canopy, look.landHigh.xyz, smoothstep(0.1, 0.6, height));
    canopy = mix(canopy, look.landCrest.xyz, smoothstep(0.55, 1.0, height) * 0.8);
    canopy *= 1.0 + look.clumpDepth * (clump - 0.5) * 2.0;
    canopy = mix(canopy, look.petalDeep.xyz * 0.92, saturate((0.44 - clump) * 3.0) * 0.28);
    float speckle = look.blossomDensity * 0.3 * (1.0 - bloomDetail) + look.budDensity * 0.25 * (1.0 - budDetail);
    canopy = mix(canopy, look.petalLight.xyz, speckle * 0.45);
    float3 bloomColor = mix(look.petalLight.xyz, look.petalDeep.xyz, saturate(bloom.depth * 1.3) * 0.75 + bloom.tint * 0.25);
    bloomColor = mix(bloomColor, look.blossomEye.xyz, bloom.eye);
    canopy = mix(canopy, bloomColor, max(bloom.coverage, bloom.eye) * bloomDetail);
    float3 budColor = mix(look.petalLight.xyz, look.petalDeep.xyz, 0.35 + bud.tint * 0.5);
    budColor = mix(budColor, look.blossomEye.xyz, bud.eye * 0.8);
    canopy = mix(canopy, budColor, max(bud.coverage, bud.eye) * budDetail * 0.9);
    float petals = max(bloom.coverage * bloomDetail, bud.coverage * budDetail);

    float seaward = max(-coast, 0.0);
    float shallow = exp(-seaward / look.shallowWidth);
    float3 sea = mix(look.seaDeep.xyz, look.seaOpen.xyz, exp(-seaward / (look.shallowWidth * 5.0)));
    sea = mix(sea, look.seaShallow.xyz, shallow);
    sea = mix(sea, look.seaShore.xyz, exp(-seaward / look.shoreWidth) * 0.55);
    float raftAmount = 0.0;
    float raftTint = 0.0;
    if (water > 0.0) {
        float drift = exp(-seaward / look.raftWidth) * smoothstep(0.35, 0.75, sakuraNoise(nG * 38.0 + 3.0));
        float raftDetail = 1.0 - smoothstep(0.35, 0.8, footprint / look.raftSize);
        float floating = 0.0;
        if (drift > 0.02 && raftDetail > 0.0) {
            floating = sakuraRaftPetal(coordinates.uv, cosLatitude, look.raftSize, look.raftDensity * drift, 29.0, footprint, raftTint);
        }
        raftAmount = mix(drift * look.raftDensity * 0.12 * exp(-seaward / (look.raftWidth * 0.5)), floating, raftDetail);
    }
    float3 raftColor = look.raft.xyz * (0.92 + 0.16 * raftTint);
    sea = mix(sea, raftColor, raftAmount);

    float nl = dot(nM, sun);
    float diffuse = saturate((nl + look.wrap) / (1.0 + look.wrap));
    float3 studioKey = normalize(-uniforms.cameraForward.xyz * 0.7 + uniforms.cameraUp.xyz * 0.6 - uniforms.cameraRight.xyz * 0.45);
    float modelling = mix(0.86, 1.05, saturate(dot(nM, studioKey) * 0.5 + 0.5));
    float3 landDay = mix(canopy * look.landShade.xyz * 1.15, canopy, diffuse) * modelling;
    float seaLight = mix(0.8, 1.0, saturate(muG * 3.0));
    float3 seaDay = mix(sea * seaLight, raftColor * mix(0.75, 1.0, diffuse), raftAmount);
    float3 day = mix(landDay, seaDay, water);

    float warmth = (1.0 - smoothstep(0.0, look.twilightWidth, muG)) * smoothstep(-0.07, 0.03, muG);
    day = mix(day, day * look.dusk.xyz * 1.35, warmth * mix(0.4, 0.25, water));
    float back = saturate(dot(direction, sun));
    float transmit = look.transmission * warmth * (0.3 + 0.7 * back) * land * (0.55 + 0.45 * petals);

    float viewCosine = saturate(dot(nG, view));
    float facing = saturate(dot(nM, view));
    float3 nightLand = look.landNight.xyz * (0.8 + 0.35 * height) * (1.0 + 0.15 * petals);
    float3 nightSea = look.seaNight.xyz * (1.0 + 0.7 * shallow);
    nightSea = mix(nightSea, look.landNight.xyz * 0.9, raftAmount);
    float3 night = mix(nightLand, nightSea, water) * (0.75 + 0.25 * facing);
    night += look.landNight.xyz * look.nightLift * facing * land;

    float3 color = mix(night, day, dayGate);
    color += look.glow.xyz * transmit;

    float3 halfway = normalize(sun + view);
    float glint = pow(saturate(dot(nG, halfway)), look.glintPower) * look.glintStrength * water * (1.0 - raftAmount);
    color += look.glint.xyz * glint * dayGate;
    color += look.petalLight.xyz * look.sheen * pow(1.0 - facing, 4.0) * dayGate * land;

    float city = (pow(lights, 1.5) + 0.3 * lightsHalo) * nightGate * land * look.cityGlow;
    color += look.cityLight.xyz * city;

    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        float hollow = saturate(effects.state.z * effects.dent.w * pressWeight);
        color = mix(color, color * mix(look.landShade.xyz * 1.25, look.seaDeep.xyz * 2.0, water), hollow);
    }

    float hazeAmount = look.haziness * pow(1.0 - viewCosine, 2.5);
    color = mix(color, mix(look.nightHaze.xyz, look.haze.xyz, dayGate), hazeAmount);
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 sakuraBackground(FullscreenVertex in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant SakuraLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float scale = uniforms.viewport.x / 1206.0;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = mix(look.backdrop.xyz, look.blush.xyz, smoothstep(-0.3, 0.45, screen.y));
    float bands = 0.0;
    for (int index = 0; index < 3; index++) {
        float center = -0.28 + 0.26 * float(index);
        float wave = 0.012 * sin(screen.x * (5.0 + float(index) * 2.0) + float(index) * 1.7);
        float offset = (screen.y - center - wave) / (0.03 + 0.01 * float(index));
        bands += exp(-offset * offset) * (0.7 - 0.15 * float(index));
    }
    color = mix(color, float3(1.0), saturate(bands) * look.mist * 0.35);
    float3 eye = uniforms.cameraPosition.xyz;
    float eyeDistance = length(eye);
    float pointScale = uniforms.viewport.x / 402.0;
    float cell = look.patternSize * pointScale * pow(3.85 / max(eyeDistance, 1.0), 0.2);
    float yaw = atan2(eye.x, eye.z);
    float pitch = asin(clamp(eye.y / max(eyeDistance, 1e-4), -1.0, 1.0));
    float2 drifted = pixel + float2(-yaw, pitch) * cell * look.patternTurns / M_PI_F;
    float2 motif = drifted / cell;
    float line = sakuraSeigaiha(motif, 0.45 * pointScale / cell, 0.6 / cell);
    float open = smoothstep(1.04, 1.35, reach);
    color = mix(color, look.patternInk.xyz, line * look.patternStrength * open);
    float fiber = sakuraNoise(float3(drifted.x * 0.9 / pointScale, drifted.y * 0.14 / pointScale, 3.0)) * 0.6
                + sakuraNoise(float3(drifted / (pointScale * 2.2), 11.0)) * 0.4;
    color *= 1.0 + (fiber - 0.5) * look.grain * open;
    color = mix(color, look.haze.xyz, 0.45 * exp(-max(reach - 1.0, 0.0) * 6.0));
    BackdropPoint drift = backdropPoint(direction, 24.0, 7.0, focal);
    if (drift.random.x < look.drift) {
        float near = drift.random.y * drift.random.y;
        float size = look.driftSize * mix(0.8, 2.6, near) * scale;
        float angle = drift.random.z * 6.2831853;
        float2 axis = float2(cos(angle), sin(angle));
        float2 local = float2(dot(drift.offset, axis), dot(drift.offset, float2(-axis.y, axis.x))) / size;
        float softness = mix(0.9, 5.0, near) * scale / size;
        float petal = saturate(0.5 - sakuraPetalShape(local) / max(softness, 1e-3));
        float3 tint = mix(look.petalDeep.xyz, look.petalLight.xyz, 0.35 + 0.4 * hash33(float3(drift.random.zy, 3.0)).x);
        color = mix(color, tint, petal * mix(0.9, 0.5, near));
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 sakuraPetal(PetalFragmentIn in [[stage_in]],
                           bool front [[front_facing]],
                           constant GlobeUniforms &uniforms [[buffer(0)]],
                           constant SakuraLook &look [[buffer(1)]]) {
    float2 p = in.local;
    float shape = sakuraPetalShape(p);
    float coverage = saturate(0.5 - shape / max(fwidth(shape), 1e-4));
    if (coverage <= 0.0) {
        discard_fragment();
    }
    float3 normal = normalize(in.normal) * (front ? 1.0 : -1.0);
    float3 sun = uniforms.sunDirection.xyz;
    float3 position = in.worldPosition;
    float3 toCamera = normalize(uniforms.cameraPosition.xyz - position);
    float along = dot(position, sun);
    float axial = sqrt(max(dot(position, position) - along * along, 0.0));
    float lit = along > 0.0 ? 1.0 : smoothstep(0.96, 1.08, axial);
    float facing = dot(normal, sun);
    float diffuse = 0.78 + 0.22 * abs(facing);
    float through = saturate(-dot(normal, toCamera) * sign(facing) + 0.2) * saturate(dot(-toCamera, sun) * 0.5 + 0.6);
    float base = saturate(0.5 - p.x * 0.5);
    float3 petal = mix(look.petalLight.xyz, look.petalDeep.xyz, base * 0.85 + in.random * 0.2);
    petal = mix(petal, look.blossomEye.xyz, smoothstep(0.6, 1.0, base) * 0.3);
    float3 day = petal * diffuse + look.glow.xyz * through * look.petalTranslucency * 0.35;
    float3 night = look.landNight.xyz * (0.9 + 0.3 * base) + look.nightHaze.xyz * 0.2;
    float3 color = mix(night, day, lit);
    half4 result = finishColor(color, in.position.xy);
    result.a = half(coverage);
    return result;
}
