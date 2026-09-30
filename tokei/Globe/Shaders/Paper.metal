#include "GlobeShared.h"

struct PaperLook {
    float4 backdrop;
    float4 seaDeep;
    float4 seaOpen;
    float4 seaShelf;
    float4 seaShallow;
    float4 seaCoast;
    float4 landCoast;
    float4 landLow;
    float4 landMid;
    float4 landHigh;
    float4 landTop;
    float4 surf;
    float4 shade;
    float4 golden;
    float4 dusk;
    float4 duskDeep;
    float4 night;
    float4 cityLight;
    float4 pinhole;
    float4 pop;
    float4 seaSteps;
    float4 landSteps;
    float contourWobble;
    float deckle;
    float grain;
    float grainCell;
    float shadowReach;
    float shadowLimit;
    float shadowSoftness;
    float shadowStrength;
    float occlusionWidth;
    float occlusionStrength;
    float edgeLight;
    float edgeWidth;
    float surfOffset;
    float surfWidth;
    float daylightFloor;
    float goldenWidth;
    float duskDepth;
    float duskSaturation;
    float nightSaturation;
    float nightLift;
    float crestWidth;
    float crestLight;
    float creaseLine;
    float foldShadow;
    float limbShade;
    float outline;
    float keyLight;
    float effectRelief;
    float pinholeSpacing;
    float pinholeSize;
    float pinholeThreshold;
    float pinholeGlow;
    float glow;
    float halo;
    float popHeight;
    float popSize;
    float popPetals;
    float popTwist;
    float popShadow;
    float popShadowReach;
};

static float paperHash(float3 p) {
    p = fract(p * 0.1031);
    p += dot(p, p.zyx + 31.32);
    return fract((p.x + p.y) * p.z);
}

static float paperNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float lowerNear = mix(paperHash(cell), paperHash(cell + float3(1.0, 0.0, 0.0)), t.x);
    float lowerFar = mix(paperHash(cell + float3(0.0, 1.0, 0.0)), paperHash(cell + float3(1.0, 1.0, 0.0)), t.x);
    float upperNear = mix(paperHash(cell + float3(0.0, 0.0, 1.0)), paperHash(cell + float3(1.0, 0.0, 1.0)), t.x);
    float upperFar = mix(paperHash(cell + float3(0.0, 1.0, 1.0)), paperHash(cell + float3(1.0, 1.0, 1.0)), t.x);
    return mix(mix(lowerNear, lowerFar, t.y), mix(upperNear, upperFar, t.y), t.z) - 0.5;
}

static float paperWave(float3 p, float3 axis, float phase) {
    float t = fract(dot(p, axis) + phase) - 0.5;
    return t * t;
}

static float paperGrain(float3 p) {
    float sum = paperWave(p, float3(0.5091, 0.2153, 0.8333), 0.0)
              + paperWave(p, float3(-0.8160, 0.2901, 0.5000), 0.618)
              + paperWave(p, float3(0.4619, -0.8711, 0.1667), 0.236)
              + paperWave(p, float3(0.2479, 0.9544, -0.1667), 0.854)
              + paperWave(p, float3(-0.7267, -0.4710, -0.5000), 0.472)
              + paperWave(p, float3(0.5451, -0.0916, -0.8333), 0.09);
    return 2.0 * sum - 1.0;
}

static float2 paperUV(float3 direction) {
    float longitude = atan2(direction.x, direction.z);
    float latitude = asin(clamp(direction.y, -1.0, 1.0));
    return float2(longitude / (2.0 * M_PI_F) + 0.5, 0.5 - latitude / M_PI_F);
}

static float paperNearest(float4 gaps) {
    float4 ahead = select(float4(1e4), gaps, gaps >= 0.0);
    return min(min(ahead.x, ahead.y), min(ahead.z, ahead.w));
}

static float paperRise(float tier, float4 seaSteps, float4 landSteps) {
    float coastGap = -tier >= 0.0 ? -tier : 1e4;
    return min(min(paperNearest(seaSteps - tier), paperNearest(landSteps - tier)), coastGap);
}

static float paperFall(float tier, float4 seaSteps, float4 landSteps) {
    float coastGap = tier > 0.0 ? tier : 1e4;
    return min(min(paperNearest(tier - seaSteps), paperNearest(tier - landSteps)), coastGap);
}

static float paperRosette(float2 local, float radius, float petals, float twist, float softness) {
    float angle = atan2(local.y, local.x) + twist;
    float edge = radius * (1.0 + 0.14 * cos(petals * angle));
    return saturate((edge - length(local)) / softness + 0.5);
}

static float paperPerforation(float2 local, float radius, float count, float twist, float softness) {
    float step = 2.0 * M_PI_F / count;
    float angle = round((atan2(local.y, local.x) + twist) / step) * step - twist;
    float2 hole = float2(cos(angle), sin(angle)) * radius * 0.68;
    return saturate((radius * 0.05 - length(local - hole)) / softness + 0.5);
}

fragment half4 paperFragment(MeshFragmentIn in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant PaperLook &look [[buffer(1)]],
                             constant EffectUniforms &effects [[buffer(2)]],
                             texture2d<float> dayTexture [[texture(0)]],
                             texture2d<float> lightsTexture [[texture(1)]],
                             texture2d<float> coastTexture [[texture(2)]],
                             texture2d<float> reliefTexture [[texture(3)]],
                             sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float twilightWidth = max(fwidth(muG), 1e-4);
    float pixelAngle = max(max(length(dfdx(nG)), length(dfdy(nG))), 1e-6);
    float viewCosine = saturate(dot(nG, -direction));
    float outlineWidth = max(fwidth(viewCosine), 1e-4);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float wobble = reliefTexture.sample(surfaceSampler, coordinates.uv, level(2.0)).w;
    float zoom = sqrt(max(dot(uniforms.cameraPosition.xyz, uniforms.cameraPosition.xyz) - 1.0, 0.0)) / 3.72;
    float mottleCell = look.grainCell * M_PI_F / 180.0 * clamp(zoom, 0.35, 1.6);
    float mottle = paperGrain(nG / mottleCell) * saturate(mottleCell / pixelAngle / 3.0 - 1.0);
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;

    float stretch = 1.0 + look.contourWobble * wobble;
    float plain = coast * stretch;
    float width = max(fwidth(plain), 1e-4);
    float inflate = max(effects.radii.w, 0.0);
    float height = saturate(inflate);
    float4 seaSteps = look.seaSteps / max(inflate, 0.05);
    float4 landSteps = look.landSteps / max(inflate, 0.05);
    float rise = paperRise(plain, seaSteps, landSteps);
    float fall = paperFall(plain, seaSteps, landSteps);
    float fineFade = saturate(1.0 / (630.0 * pixelAngle) - 1.0);
    float tier = plain;
    if (fineFade > 0.0 && min(rise, fall) < look.deckle + 4.0 * width) {
        tier += look.deckle * paperNoise(nG * 210.0) * fineFade;
        rise = paperRise(tier, seaSteps, landSteps);
        fall = paperFall(tier, seaSteps, landSteps);
    }
    float4 seaCover = saturate((tier - seaSteps) / width + 0.5);
    float4 landCover = saturate((tier - landSteps) / width + 0.5);
    float coastCover = saturate(tier / width + 0.5);
    float water = 1.0 - coastCover;

    float3 paper = look.seaDeep.xyz;
    paper = mix(paper, look.seaOpen.xyz, seaCover.w);
    paper = mix(paper, look.seaShelf.xyz, seaCover.z);
    paper = mix(paper, look.seaShallow.xyz, seaCover.y);
    paper = mix(paper, look.seaCoast.xyz, seaCover.x);
    paper = mix(paper, look.landCoast.xyz, coastCover);
    paper = mix(paper, look.landLow.xyz, landCover.x);
    paper = mix(paper, look.landMid.xyz, landCover.y);
    paper = mix(paper, look.landHigh.xyz, landCover.z);
    paper = mix(paper, look.landTop.xyz, landCover.w);

    float surfWidth = max(look.surfWidth, 1.2 * width);
    float surf = saturate((tier + look.surfOffset + surfWidth) / width + 0.5) * (1.0 - saturate((tier + look.surfOffset) / width + 0.5));
    paper = mix(paper, look.surf.xyz, surf);

    float lowerSide = saturate(rise / width + 0.5);
    float upperSide = saturate(0.5 - fall / width);
    float occlusionWidth = max(look.occlusionWidth, 1.5 * width);
    float occlusion = max(exp(-rise / occlusionWidth) * lowerSide, upperSide);

    float cast = 0.0;
    float edge = 0.0;
    if (muG > 0.0 && inflate > 0.0) {
        float3 sunAcross = sun - nG * muG;
        float sunAcrossLength = max(length(sunAcross), 1e-4);
        float reach = min(look.shadowReach * sunAcrossLength / max(muG, 0.05), look.shadowLimit) * inflate;
        float3 probe = normalize(nG + sunAcross * (reach * M_PI_F / 180.0 / sunAcrossLength));
        float probeLevel = coastTexture.sample(surfaceSampler, paperUV(probe), level(max(log2(pixelAngle * float(coastTexture.get_width()) / (2.0 * M_PI_F)), 0.0))).r * stretch;
        float soft = look.shadowSoftness + 0.35 * reach;
        cast = saturate((probeLevel - tier - rise) / soft + 0.5) * lowerSide;
        edge = exp(-fall / (look.edgeWidth * width)) * saturate((tier - fall - probeLevel) / soft + 0.5) * (1.0 - upperSide);
    }

    float sunFade = smoothstep(0.0, 0.08, muG);
    float fibre = 1.0 + look.grain * mottle;
    float dayShadow = saturate(look.shadowStrength * cast * sunFade + look.occlusionStrength * occlusion * height);
    float3 dayPaper = paper * mix(float3(1.0), look.shade.xyz, dayShadow) * fibre;
    dayPaper += look.surf.xyz * edge * look.edgeLight * sunFade * height;

    float3 surfaceNormal = nG;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        surfaceNormal = normalize(nG - slope);
    }

    float daylight = mix(look.daylightFloor, 1.0, smoothstep(0.0, 0.6, muG));
    float goldenAmount = (1.0 - smoothstep(0.0, look.goldenWidth, muG)) * (1.0 - 0.7 * water);
    float3 key = normalize(uniforms.cameraUp.xyz * 0.6 - uniforms.cameraRight.xyz * 0.45 - uniforms.cameraForward.xyz * 0.65);
    float3 bend = surfaceNormal - nG;
    float relight = 1.0 + dot(bend, sun) * saturate(muG * 6.0) + look.effectRelief * dot(bend, key);
    float3 color = dayPaper * daylight * mix(float3(1.0), look.golden.xyz, goldenAmount) * relight;
    float civil = saturate(-muG / twilightWidth + 0.5);
    float foldWidth = max(look.crestWidth, 2.0 * twilightWidth);
    if (civil > 0.0) {
        float3 nightPaper = paper * mix(float3(1.0), look.shade.xyz, saturate(look.occlusionStrength * occlusion * height)) * fibre;
        float3 nightLuma = float3(dot(nightPaper, float3(0.2126, 0.7152, 0.0722)));
        float dusk = smoothstep(0.0, 1.0, saturate(-muG / look.duskDepth));
        float3 duskTint = mix(look.dusk.xyz, look.duskDeep.xyz, saturate(dusk * 2.0));
        duskTint = mix(duskTint, look.night.xyz, saturate(dusk * 2.0 - 1.0));
        float duskSaturation = mix(look.duskSaturation, look.nightSaturation, dusk);
        float3 twilight = (look.nightLift * dusk + (1.0 - look.nightLift * dusk) * mix(nightLuma, nightPaper, duskSaturation)) * duskTint;
        twilight *= 1.0 + look.crestLight * exp(-max(-muG, 0.0) / foldWidth);
        color = mix(color, twilight * relight, civil);
    }
    if (abs(muG) < 8.0 * foldWidth) {
        color *= 1.0 - look.foldShadow * exp(-max(muG, 0.0) / foldWidth) * (1.0 - civil);
        color *= 1.0 - look.creaseLine * exp(-abs(muG) / twilightWidth);
    }

    float lightGate = smoothstep(0.0, -0.2, muG) * (1.0 - water);
    if (lightGate > 0.0) {
        gradient2d glowGradient = gradient2d(coordinates.dx * 2.5, coordinates.dy * 2.5);
        gradient2d haloGradient = gradient2d(coordinates.dx * 8.0, coordinates.dy * 8.0);
        float glowLight = lightsTexture.sample(surfaceSampler, coordinates.uv, glowGradient).r;
        float haloLight = lightsTexture.sample(surfaceSampler, coordinates.uv, haloGradient).r;
        float spacing = look.pinholeSpacing * M_PI_F / 180.0;
        float latitude = (0.5 - coordinates.uv.y) * M_PI_F;
        float row = floor(latitude / spacing);
        float columns = max(floor(2.0 * M_PI_F * cos((row + 0.5) * spacing) / spacing), 1.0);
        float column = floor(coordinates.uv.x * columns);
        float3 jitter = hash33(float3(row, column, 5.0));
        float holeLatitude = (row + 0.3 + 0.4 * jitter.x) * spacing;
        float holeLongitude = ((column + 0.3 + 0.4 * jitter.y) / columns - 0.5) * 2.0 * M_PI_F;
        float3 hole = float3(cos(holeLatitude) * sin(holeLongitude), sin(holeLatitude), cos(holeLatitude) * cos(holeLongitude));
        float2 holeUV = float2(holeLongitude / (2.0 * M_PI_F) + 0.5, 0.5 - holeLatitude / M_PI_F);
        float holeLight = lightsTexture.sample(surfaceSampler, holeUV, glowGradient).r;
        float holeDistance = length(nG - hole);
        float holeStrength = smoothstep(look.pinholeThreshold, 0.6, holeLight);
        float holeRadius = spacing * look.pinholeSize * sqrt(holeStrength);
        float holeFade = saturate(spacing / pixelAngle / 3.0 - 0.5);
        float punched = saturate((holeRadius - holeDistance) / pixelAngle + 0.5) * saturate(2.0 * holeRadius / pixelAngle) * holeFade;
        float holeGlow = exp(-holeDistance * holeDistance / (spacing * spacing * 0.012)) * holeFade * holeStrength;
        float3 lantern = look.cityLight.xyz * (look.glow * pow(glowLight, 1.4) + look.halo * pow(haloLight, 1.1))
                       + look.pinhole.xyz * (punched + look.pinholeGlow * holeGlow);
        color += lantern * lightGate;
    }

    float limb = mix(look.limbShade, 1.0, sqrt(viewCosine)) * (1.0 + look.keyLight * (dot(nG, key) - 0.5));
    color *= limb;
    float rimLine = 1.0 - smoothstep(0.0, 2.0 * outlineWidth, viewCosine);
    color = mix(color, color * look.shade.xyz, rimLine * look.outline);
    if (effectsActive(effects)) {
        float hollow = effects.dent.w * effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * hollow);
        float popAmount = effects.bump.w / max(look.popHeight, 1e-4);
        float popReach = effects.radii.y * look.popSize * 1.4 + effects.bump.w * look.popShadowReach + 2.0 * pixelAngle;
        if (popAmount > 0.0 && length(nG - effects.bump.xyz) < popReach) {
            float3 center = effects.bump.xyz;
            float3 east = normalize(cross(float3(0.0, 1.0, 0.0), center) + float3(1e-5, 0.0, 0.0));
            float3 north = cross(center, east);
            float3 offset = nG - center;
            float2 local = float2(dot(offset, east), dot(offset, north));
            float2 lightAcross = float2(dot(key, east), dot(key, north));
            float2 shift = -lightAcross / max(length(lightAcross), 1e-4) * effects.bump.w * look.popShadowReach;
            float radius = effects.radii.y * look.popSize * clamp(zoom, 0.6, 1.0) * sqrt(saturate(popAmount));
            float twist = (1.0 - saturate(popAmount)) * look.popTwist;
            float rosette = paperRosette(local, radius, look.popPetals, twist, pixelAngle);
            float rosetteShadow = paperRosette(local - shift, radius, look.popPetals, twist, pixelAngle + 0.25 * radius);
            float perforation = paperPerforation(local, radius, 2.0 * look.popPetals, twist, pixelAngle);
            float3 lantern = (look.pop.xyz * mix(1.0, 0.3, civil) + look.cityLight.xyz * civil) * (1.0 - 0.3 * perforation);
            color *= 1.0 - look.popShadow * rosetteShadow * (1.0 - rosette);
            color = mix(color, lantern * limb, rosette);
        }
    }
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

static float paperValueNoise(float2 point) {
    float2 cell = floor(point);
    float2 f = fract(point);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash12(cell);
    float b = hash12(cell + float2(1.0, 0.0));
    float c = hash12(cell + float2(0.0, 1.0));
    float d = hash12(cell + float2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

static float paperConfetti(float2 offset, float size, bool star) {
    if (!star) {
        return length(offset) - size;
    }
    float2 folded = abs(offset) / (size * 1.6);
    return (sqrt(folded.x) + sqrt(folded.y) - 1.0) * size * 1.2;
}

static float3 paperConfettiLayer(float3 color, float2 point, float cellSize, float chance, float sizeScale, float seed,
                                 float fade, float castAmount, float scale, constant PaperLook &look) {
    float2 cell = floor(point / cellSize);
    float3 random = hash33(float3(cell, seed));
    if (random.x >= chance) {
        return color;
    }
    float2 center = (cell + 0.2 + 0.6 * hash33(float3(cell, seed + 12.0)).xy) * cellSize;
    float size = (3.5 + 4.0 * random.y) * scale * sizeScale;
    float3 tint = random.z < 0.34 ? look.landLow.xyz : (random.z < 0.67 ? look.seaShallow.xyz : look.landHigh.xyz);
    bool star = hash12(cell + 3.7 + (seed - 7.0)) < 0.35;
    float cast = saturate(0.5 - paperConfetti(point - center - float2(1.4, 2.0) * scale * sizeScale, size, star));
    float confetti = saturate(0.5 - paperConfetti(point - center, size, star));
    color = mix(color, color * 0.82, 0.7 * cast * castAmount);
    return mix(color, mix(tint, look.backdrop.xyz, fade), confetti);
}

fragment half4 paperBackground(FullscreenVertex in [[stage_in]],
                               constant GlobeUniforms &uniforms [[buffer(0)]],
                               constant PaperLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float scale = uniforms.viewport.x / 1206.0;
    float3 disk = globeDisk(uniforms);
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float mottle = paperValueNoise(pixel / (170.0 * scale)) - 0.5;
    float fiber = paperValueNoise(float2(pixel.x / (2.5 * scale), pixel.y / (36.0 * scale))) - 0.5;
    float speck = hash12(floor(pixel / (1.5 * scale))) - 0.5;
    float3 color = look.backdrop.xyz * (1.0 + mottle * 0.05 + fiber * 0.05 + speck * 0.03);
    color *= mix(1.02, 0.9, smoothstep(0.3, 0.85, length(screen)));
    float shadowReach = length(pixel - disk.xy - float2(0.05, 0.09) * disk.z) / disk.z;
    color = mix(color, look.shade.xyz * 0.85, 0.4 * (1.0 - smoothstep(0.9, 1.14, shadowReach)));
    float3 eye = uniforms.cameraPosition.xyz;
    float eyeDistance = max(length(eye), 1.0);
    float2 turn = float2(-atan2(eye.x, eye.z), asin(clamp(eye.y / eyeDistance, -1.0, 1.0))) / (2.0 * M_PI_F);
    float farCell = 64.0 * scale * pow(3.85 / eyeDistance, 0.1);
    color = paperConfettiLayer(color, pixel + turn * farCell * 4.0, farCell, 0.22, 0.6, 31.0, 0.45, 0.0, scale, look);
    float nearCell = 96.0 * scale * pow(3.85 / eyeDistance, 0.2);
    color = paperConfettiLayer(color, pixel + turn * nearCell * 10.0, nearCell, 0.32, 1.0, 7.0, 0.0, 1.0, scale, look);
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
