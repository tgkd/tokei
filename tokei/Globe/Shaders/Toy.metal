#include "GlobeShared.h"

struct ToyLook {
    float4 backdrop;
    float4 oceanDeep;
    float4 oceanShallow;
    float4 oceanNight;
    float4 foam;
    float4 landLow;
    float4 landHigh;
    float4 landNight;
    float4 cityLight;
    float4 twilight;
    float4 fill;
    float4 rim;
    float4 shine;
    float wrap;
    float gloss;
    float clearcoat;
    float sheen;
    float shallowWidth;
    float foamWidth;
    float shadowLength;
    float shadowStrength;
    float softbox;
    float nightReflection;
    float form;
    float rimLight;
    float ledSize;
    float ledGlow;
    float twilightWidth;
    float landGloss;
};

static float toyFresnel(float cosine) {
    float grazing = 1.0 - saturate(cosine);
    float grazing2 = grazing * grazing;
    return 0.04 + 0.96 * grazing2 * grazing2 * grazing;
}

static float toySoftbox(float3 reflected, float3 right, float3 up, float3 back) {
    float3 center = normalize(back * 0.9 + up * 0.75 - right * 0.6);
    float3 boxRight = normalize(cross(up, center));
    float3 boxUp = cross(center, boxRight);
    float facing = dot(reflected, center);
    float2 local = float2(dot(reflected, boxRight), dot(reflected, boxUp)) / max(facing, 0.05);
    float2 corner = abs(local) - float2(0.28, 0.2) + 0.09;
    float distance = length(max(corner, 0.0)) + min(max(corner.x, corner.y), 0.0) - 0.09;
    float panel = 1.0 - smoothstep(-0.06, 0.04, distance);
    float falloff = saturate(local.y / 0.4 + 0.5);
    return panel * step(0.0, facing) * (0.25 + 0.75 * falloff * falloff);
}

static float toyStrip(float3 reflected, float3 right, float3 up, float3 back) {
    float3 strip = normalize(-back * 0.55 + right * 0.8 + up * 0.25);
    return smoothstep(0.55, 0.85, dot(reflected, strip));
}

static float toyLEDs(float2 uv, float footprint, float size, float seed, texture2d<float> lightsTexture, sampler surfaceSampler) {
    float latitude = (0.5 - uv.y) * 180.0;
    float band = (latitude + 90.0) / size;
    float row = floor(band);
    float rowLatitude = (row + 0.5) * size - 90.0;
    float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / size), 1.0);
    float along = fract(uv.x) * columns;
    float column = floor(along);
    float3 random = hash33(float3(column, row, seed));
    float3 shape = hash33(float3(row, column, seed + 3.0));
    float2 spot = 0.15 + 0.7 * random.xy;
    float2 spotUV = float2((column + spot.x) / columns, 0.5 - ((row + spot.y) * size - 90.0) / 180.0);
    float light = lightsTexture.sample(surfaceSampler, spotUV, level(log2(max(size / 0.088, 1.0)))).r;
    float lit = smoothstep(random.z * 0.6, random.z * 0.6 + 0.06, light);
    float2 offset = float2(fract(along), band - row) - spot;
    float pixels = length(offset) * size / max(footprint, 1e-5);
    float radius = 0.8 + 0.7 * shape.x;
    float core = exp(-pixels * pixels / (2.0 * radius * radius));
    float halo = exp(-dot(offset, offset) / 0.012) * 0.3;
    return lit * (0.3 + 0.7 * shape.y * shape.y) * (core + halo) * saturate(light * 3.0);
}

fragment half4 toyFragment(MeshFragmentIn in [[stage_in]],
                           constant GlobeUniforms &uniforms [[buffer(0)]],
                           constant ToyLook &look [[buffer(1)]],
                           constant EffectUniforms &effects [[buffer(2)]],
                           texture2d<float> dayTexture [[texture(0)]],
                           texture2d<float> lightsTexture [[texture(1)]],
                           texture2d<float> coastTexture [[texture(2)]],
                           texture2d<float> reliefTexture [[texture(3)]],
                           sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 cameraRight = uniforms.cameraRight.xyz;
    float3 cameraUp = uniforms.cameraUp.xyz;
    float3 cameraBack = -uniforms.cameraForward.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), 0.012);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d softGradient = gradient2d(coordinates.dx * 4.0, coordinates.dy * 4.0);
    gradient2d haloGradient = gradient2d(coordinates.dx * 6.0, coordinates.dy * 6.0);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nMap = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float coastWidth = fwidth(coast);
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float3 nM = normalize(mix(nMap, nG, water));
    float relief = saturate(normalHeight.w);
    float cosLatitude = max(length(nG.xz), 1e-3);
    float2 degrees = float2(360.0 * cosLatitude, 180.0);
    float footprint = max(length(coordinates.dx * degrees), length(coordinates.dy * degrees));
    float normalLength = mix(1.0, sqrt(saturate(normalLengthSquared)), smoothstep(0.2, 0.6, footprint) * (1.0 - water));
    float dayGate = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.1736, 0.0175, muG);
    float resolved = smoothstep(2.5, 5.0, look.ledSize / max(footprint, 1e-5));

    float glow = 0.0;
    if (nightGate > 0.0 && water < 1.0) {
        float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
        float halo = pow(lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r, 1.2);
        float led = 0.0;
        if (resolved > 0.0) {
            float fine = smoothstep(2.5, 5.0, look.ledSize * 0.45 / max(footprint, 1e-5));
            led = toyLEDs(coordinates.uv, footprint, look.ledSize, 7.0, lightsTexture, surfaceSampler);
            if (fine > 0.0) {
                led += 0.6 * fine * toyLEDs(coordinates.uv, footprint, look.ledSize * 0.45, 19.0, lightsTexture, surfaceSampler);
            }
        }
        glow = mix(pow(lights, 1.6) + halo * 0.35, led * 1.6 + halo * 0.3, resolved) * nightGate * (1.0 - water);
    }

    float seaward = max(-coast, 0.0);
    float castShadow = 0.0;
    if (water > 0.0 && muG > 0.0) {
        float3 east = float3(nG.z, 0.0, -nG.x) / cosLatitude;
        float3 north = cross(nG, east);
        float3 sunAlong = sun - nG * muG;
        float reach = look.shadowLength * M_PI_F / 180.0 / max(muG, 0.05);
        float2 uvPerTangent = float2(dot(sunAlong, east) / (2.0 * M_PI_F * cosLatitude), -dot(sunAlong, north) / M_PI_F);
        float2 casterUV = coordinates.uv + uvPerTangent * min(reach, 3.0 * M_PI_F / 180.0 * look.shadowLength / max(length(sunAlong), 1e-4));
        float casterCoast = coastTexture.sample(surfaceSampler, casterUV, softGradient).r;
        castShadow = smoothstep(-0.25, 0.5, casterCoast) * water * saturate(muG * 8.0) * exp(-seaward / max(look.shadowLength * 1.5, 1e-3));
    }

    float crest = 0.0;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        float3 rippleTilt;
        crest = max(rippleWave(nG, effects, rippleTilt), 0.0);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope - mix(effects.detail.z, 1.0, water) * effects.wave.x * rippleTilt);
        relief *= effects.radii.w;
    }

    float shallow = exp(-seaward / max(look.shallowWidth, 1e-3));
    float3 ocean = mix(look.oceanDeep.xyz * mix(1.0, 0.78, smoothstep(1.0, 12.0, seaward)), look.oceanShallow.xyz, shallow);
    float foamLine = (1.0 - smoothstep(look.foamWidth * 0.5, look.foamWidth + coastWidth, seaward)) * saturate(look.foamWidth / max(coastWidth, 1e-4) - 0.5);
    ocean = mix(ocean, look.foam.xyz, foamLine);
    float crown = smoothstep(0.0, 0.85, relief);
    float3 body = mix(look.landLow.xyz, look.landHigh.xyz, crown);
    body = mix(body, mix(look.landHigh.xyz, look.shine.xyz, 0.35), smoothstep(1.0, 9.0, coast) * crown * 0.45);
    float3 albedo = mix(body, ocean, water);

    float nl = dot(nM, sun);
    float diffuse = saturate((nl + look.wrap) / (1.0 + look.wrap));
    float3 studioKey = normalize(cameraBack * 0.7 + cameraUp * 0.6 - cameraRight * 0.45);
    float modelling = mix(1.0 - look.form, 1.0 + look.form * 0.35, saturate(dot(nM, studioKey) * 0.5 + 0.5));
    float3 shadowTone = albedo * mix(look.fill.xyz, albedo, 0.5) * 0.9;
    float3 day = mix(shadowTone, albedo, diffuse) * modelling;
    day *= 1.0 - look.shadowStrength * castShadow;
    float contact = water * exp(-seaward / 0.2) * (1.0 - foamLine);
    day *= 1.0 - 0.2 * contact;
    float warmth = 1.0 - smoothstep(0.0, look.twilightWidth, muG);
    day = mix(day, day * look.twilight.xyz * 2.4, warmth * mix(0.45, 0.2, water));

    float facing = saturate(dot(nM, view));
    float3 nightAlbedo = mix(look.landNight.xyz, look.oceanNight.xyz, water);
    nightAlbedo = mix(nightAlbedo, nightAlbedo * 1.6, water * shallow * 0.5);
    float3 night = nightAlbedo * (0.6 + 0.4 * facing) * mix(0.85, 1.1, saturate(dot(nM, studioKey) * 0.5 + 0.5));

    float viewCosine = saturate(dot(nG, view));
    float limb = mix(0.8, 1.0, sqrt(viewCosine));
    float3 color = mix(night, day, dayGate) * limb;

    color += look.cityLight.xyz * glow * look.ledGlow;

    float3 halfVector = sun + view;
    float3 halfway = halfVector * rsqrt(max(dot(halfVector, halfVector), 1e-8));
    float nh = saturate(dot(nM, halfway));
    float baseGloss = mix(look.landGloss, look.gloss, water);
    float gloss = baseGloss * normalLength / (normalLength + baseGloss * (1.0 - normalLength));
    float logNH = log2(max(nh, 1e-6));
    float highlight = exp2(logNH * gloss) * look.clearcoat * (gloss + 8.0) / (baseGloss + 8.0) + exp2(logNH * gloss * 0.1) * 0.1 + exp2(logNH * 20.0) * look.sheen;
    color += look.shine.xyz * highlight * dayGate * saturate(muG * 5.0);

    float3 reflected = reflect(direction, nM);
    float fresnel = toyFresnel(facing);
    float sky = saturate(0.5 + 0.5 * dot(reflected, cameraUp));
    float3 environment = look.fill.xyz * (0.15 + 0.85 * sky * sky)
                       + look.rim.xyz * look.rimLight * toyStrip(reflected, cameraRight, cameraUp, cameraBack);
    color += environment * fresnel * mix(look.nightReflection, 1.0, dayGate);
    float zoomedOut = smoothstep(1.9, 3.0, length(uniforms.cameraPosition.xyz));
    color += look.shine.xyz * look.softbox * zoomedOut * toySoftbox(reflected, cameraRight, cameraUp, cameraBack) * fresnel * dayGate;
    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        float hollow = saturate(effects.state.z * effects.dent.w * pressWeight);
        float3 squish = mix(look.landLow.xyz, look.oceanDeep.xyz, water) * 1.3;
        color = mix(color, color * squish, hollow);
        float popWeight = effectWeight(nG, effects.bump.xyz, effects.radii.y);
        color += mix(look.cityLight.xyz, look.shine.xyz, dayGate) * effects.radii.z * popWeight * popWeight;
        color += mix(look.oceanShallow.xyz, look.shine.xyz, 0.6) * effects.detail.w * crest * crest * mix(effects.detail.z, 1.0, water) * mix(0.3, 1.0, dayGate);
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

static float toySprinkle(float2 offset, float angle, float scale) {
    float2 axis = float2(cos(angle), sin(angle));
    float along = clamp(dot(offset, axis), -6.0 * scale, 6.0 * scale);
    return saturate(0.5 - (length(offset - axis * along) - 2.0 * scale));
}

fragment half4 toyBackground(FullscreenVertex in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant ToyLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float scale = uniforms.viewport.x / 1206.0;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = look.backdrop.xyz * mix(1.3, 0.7, smoothstep(0.1, 0.8, length(screen)));
    color += look.fill.xyz * 0.06 * exp(-max(reach - 1.0, 0.0) * 2.0);
    BackdropPoint sprinkle = backdropPoint(direction, 34.0, 5.0, focal);
    if (sprinkle.random.x < 0.42) {
        float pick = sprinkle.random.y;
        float3 tint = pick < 0.3 ? look.landLow.xyz : (pick < 0.6 ? look.oceanShallow.xyz : (pick < 0.82 ? look.cityLight.xyz : look.shine.xyz));
        color = mix(color, tint * 0.8, 0.5 * toySprinkle(sprinkle.offset, sprinkle.random.z * 6.2831853, scale));
    }
    BackdropPoint sugar = backdropPoint(direction, 105.0, 9.0, focal);
    if (sugar.random.x < 0.3) {
        color += look.shine.xyz * 0.1 * saturate(1.4 * scale - length(sugar.offset));
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
