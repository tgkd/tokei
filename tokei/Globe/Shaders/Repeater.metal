#include "GlobeShared.h"

struct RepeaterLook {
    float4 backdrop;
    float4 backdropShade;
    float4 sunray;
    float4 enamelDeep;
    float4 enamelShallow;
    float4 silver;
    float4 silverShade;
    float4 gold;
    float4 goldShade;
    float4 nightEnamel;
    float4 nightSilver;
    float4 lume;
    float4 twilight;
    float4 ink;
    float waveSpacing;
    float waveWobble;
    float waveDepth;
    float flankTilt;
    float flankSharpness;
    float flankStrength;
    float hobnailCell;
    float hobnailTilt;
    float highland;
    float wireWidth;
    float clearcoat;
    float clearcoatGloss;
    float lumeStrength;
    float lumeHalfTime;
    float lumeExponent;
    float terminatorWidth;
    float loupeRadius;
    float loupeMagnification;
    float loupeDepth;
    float sunrayLines;
    float sunraySheen;
    float chapterRing;
    float rimLight;
    float lineWidth;
};

struct RepeaterCell {
    float2 offset;
    float3 random;
};

static float repeaterWrap(float angle) {
    return angle - 2.0 * M_PI_F * floor(angle / (2.0 * M_PI_F) + 0.5);
}

static float repeaterNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float lowerNear = mix(hash33(cell).x, hash33(cell + float3(1.0, 0.0, 0.0)).x, t.x);
    float lowerFar = mix(hash33(cell + float3(0.0, 1.0, 0.0)).x, hash33(cell + float3(1.0, 1.0, 0.0)).x, t.x);
    float upperNear = mix(hash33(cell + float3(0.0, 0.0, 1.0)).x, hash33(cell + float3(1.0, 0.0, 1.0)).x, t.x);
    float upperFar = mix(hash33(cell + float3(0.0, 1.0, 1.0)).x, hash33(cell + float3(1.0, 1.0, 1.0)).x, t.x);
    return mix(mix(lowerNear, lowerFar, t.y), mix(upperNear, upperFar, t.y), t.z);
}

static RepeaterCell repeaterCell(float2 uv, float cosLatitude, float cell, float seed) {
    float latitude = (0.5 - uv.y) * 180.0;
    float band = (latitude + 90.0) / cell;
    float row = floor(band);
    float rowLatitude = (row + 0.5) * cell - 90.0;
    float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / cell), 1.0);
    float along = fract(uv.x) * columns;
    float column = floor(along);
    RepeaterCell result;
    result.random = hash33(float3(column, row, seed));
    float cellWidth = 360.0 * cosLatitude / columns;
    result.offset = float2((fract(along) - 0.5) * cellWidth, (band - row - 0.5) * cell);
    return result;
}

static float3 repeaterBump(float h, float3 nG) {
    float3 r1 = dfdx(nG);
    float3 r2 = dfdy(nG);
    float det = dot(cross(r1, r2), nG);
    float3 gradient = r1 * dfdx(h) + r2 * dfdy(h);
    return normalize(abs(det) * nG + (det >= 0.0 ? -gradient : gradient));
}

static float3 repeaterStudio(float3 reflected, constant GlobeUniforms &uniforms, constant RepeaterLook &look) {
    float up = dot(reflected, uniforms.cameraUp.xyz);
    float side = dot(reflected, uniforms.cameraRight.xyz);
    float3 environment = mix(look.silverShade.xyz * 0.55, look.sunray.xyz, smoothstep(-0.35, 0.85, up));
    float softbox = exp(-pow((up - 0.55) / 0.18, 2.0)) * exp(-pow((side + 0.35) / 0.3, 2.0));
    return environment + look.sunray.xyz * softbox * 1.6;
}

fragment half4 repeaterFragment(MeshFragmentIn in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant RepeaterLook &look [[buffer(1)]],
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
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    float pixelAngle = max(max(length(dfdx(nG)), length(dfdy(nG))), 1e-5);
    float pixelDegrees = pixelAngle * 57.29578;
    bool active = effectsActive(effects);

    float3 pD = nG;
    float loupe = 0.0;
    float loupeEdge = 0.0;
    if (active) {
        loupe = saturate(effects.dent.w / max(look.loupeDepth, 1e-5));
        if (loupe > 0.0) {
            float a = acos(clamp(dot(nG, effects.dent.xyz), -1.0, 1.0));
            float lensRadius = look.loupeRadius * loupe;
            float inside = 1.0 - smoothstep(0.85 * lensRadius, lensRadius, a);
            float magnification = 1.0 + (look.loupeMagnification - 1.0) * inside;
            pD = normalize(mix(effects.dent.xyz, nG, 1.0 / magnification));
            float rim = (a - lensRadius) / max(0.06 * lensRadius, 1e-4);
            loupeEdge = exp(-rim * rim) * loupe;
        }
    }

    SurfaceCoordinates pattern = surfaceCoordinates(pD);
    gradient2d gradient = gradient2d(pattern.dx, pattern.dy);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, pattern.uv, gradient);
    float coast = coastTexture.sample(surfaceSampler, pattern.uv, gradient).r;
    float lights = lightsTexture.sample(surfaceSampler, pattern.uv, gradient).r;
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nMap = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float relief = saturate(normalHeight.w);
    float coastWidth = max(fwidth(coast), 1e-4);
    float water = 1.0 - coastCoverage(coast, coastWidth);
    float land = 1.0 - water;
    float patternCos = max(length(pD.xz), 1e-3);
    float3 east = float3(pD.z, 0.0, -pD.x) / patternCos;
    float3 north = cross(pD, east);

    float seaward = max(-coast, 0.0);
    float wave = sin(dot(pD, float3(31.0, 9.0, -19.0))) + 0.6 * sin(dot(pD, float3(-11.0, 37.0, 14.0)));
    float seaPhase = seaward / look.waveSpacing + look.waveWobble * wave;
    float lineDensity = fwidth(seaPhase);
    float lineFade = 1.0 - smoothstep(0.22, 0.45, lineDensity);
    float lineDistance = abs(fract(seaPhase + 0.5) - 0.5) * 2.0;
    float lineCore = 1.0 - smoothstep(look.lineWidth - lineDensity * 2.0, look.lineWidth + lineDensity * 2.0, lineDistance);
    float groove = exp(-pow(lineDistance / max(look.lineWidth, 1e-3), 2.0)) * lineFade;
    float grooveHeight = -groove * look.flankTilt * look.waveSpacing * (M_PI_F / 180.0) * look.lineWidth;
    float3 flankNormal = repeaterBump(grooveHeight, nG);

    RepeaterCell lattice = repeaterCell(pattern.uv, patternCos, look.hobnailCell, 11.0);
    float2 local = lattice.offset / max(look.hobnailCell, 1e-4);
    float cellPixels = look.hobnailCell / max(pixelDegrees, 1e-5);
    float facetFade = smoothstep(3.0, 6.0, cellPixels);
    float ridgeWidth = 1.2 / max(cellPixels, 1e-3);
    float ridge = 1.0 - smoothstep(0.0, ridgeWidth, abs(abs(local.x) - abs(local.y)));
    float border = 1.0 - smoothstep(0.0, ridgeWidth, 0.5 - max(abs(local.x), abs(local.y)));
    float highland = smoothstep(look.highland, look.highland + 0.15, relief);
    float3 facet = abs(local.x) > abs(local.y) ? east * sign(local.x) : north * sign(local.y);
    float barley = sin(2.0 * M_PI_F * 4.0 * (local.x + local.y));
    float3 diagonal = normalize(east + north);
    float3 tilt = mix(facet * look.hobnailTilt, diagonal * barley * look.hobnailTilt * 0.7, highland) * facetFade;
    float3 landNormal = normalize(nMap + tilt);
    float engraving = max(ridge, border) * facetFade * (1.0 - highland);

    float wireHalf = max(look.wireWidth * 0.5, 1.1 * pixelDegrees);
    float wire = 1.0 - smoothstep(wireHalf - coastWidth * 0.75, wireHalf + coastWidth * 0.75, abs(coast));
    float across = clamp(coast / wireHalf, -1.0, 1.0);
    float3 wireNormal = repeaterBump(wireHalf * (M_PI_F / 180.0) * (1.0 - across * across) * 0.9, nG);

    float phi = asin(clamp(nG.y, -0.9999, 0.9999));
    float delta = asin(clamp(sun.y, -0.9999, 0.9999));
    float hourAngle = repeaterWrap(atan2(nG.x, nG.z) - atan2(sun.x, sun.z));
    float cosH0 = clamp(-tan(phi) * tan(delta), -1.0, 1.0);
    float hoursSinceSunset = fract((hourAngle - acos(cosH0)) / (2.0 * M_PI_F)) * 24.0;
    float lumeLevel = look.lumeStrength / pow(1.0 + hoursSinceSunset / look.lumeHalfTime, look.lumeExponent);

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float warmth = (1.0 - smoothstep(0.0, look.terminatorWidth * 5.0, muG)) * daylight;
    float viewCosine = saturate(dot(nG, view));
    float3 halfway = normalize(sun + view);
    float sunUp = saturate(muG * 5.0);

    float pulse = 0.0;
    float popGlint = 0.0;
    float lumeBoost = 1.0;
    float3 seaNormal = flankNormal;
    if (active) {
        float3 slope;
        effectOffset(nG, effects, slope);
        landNormal = normalize(mix(nG, landNormal, effects.radii.w) - slope);
        seaNormal = normalize(flankNormal - slope - effects.wave.x * rippleSlope(nG, effects));
        if (effects.detail.w > 0.0 && effects.ripple.w >= 0.0) {
            float angle = acos(clamp(dot(nG, effects.ripple.xyz), -1.0, 1.0));
            float front = angle - effects.wave.w * effects.ripple.w;
            float width = max(effects.wave.z, pixelAngle * 2.0);
            pulse = exp(-(front * front) / (width * width)) * exp(-effects.state.x * effects.ripple.w) * effects.detail.w;
        }
        popGlint = effects.radii.z * effectWeight(nG, effects.bump.xyz, effects.radii.y * 0.7);
        lumeBoost = 1.0 + 4.0 * saturate(1.0 - effects.radii.w);
    }
    lumeLevel *= lumeBoost;

    float depthNoise = repeaterNoise(pD * 18.0 + 4.0);
    float3 enamel = mix(look.enamelShallow.xyz, look.enamelDeep.xyz, saturate(0.45 + 0.25 * depthNoise + look.waveDepth * groove));
    enamel *= 1.0 - 0.3 * lineCore * lineFade;
    float seaDiffuse = saturate((dot(seaNormal, sun) + 0.35) / 1.35);
    float3 seaDay = enamel * (0.5 + 0.6 * seaDiffuse);
    float flankGlint = pow(saturate(dot(reflect(-view, seaNormal), sun)), look.flankSharpness) * look.flankStrength * lineFade;
    seaDay += look.silver.xyz * flankGlint * (1.0 + 3.0 * pulse) * sunUp;
    float3 reflectedSea = reflect(direction, nG);
    float fresnel = look.clearcoat + (1.0 - look.clearcoat) * pow(1.0 - viewCosine, 5.0);
    seaDay += repeaterStudio(reflectedSea, uniforms, look) * fresnel * 0.55;
    seaDay += look.sunray.xyz * pow(saturate(dot(nG, halfway)), look.clearcoatGloss) * 1.4 * sunUp;
    seaDay = mix(seaDay, seaDay * look.twilight.xyz * 1.7, warmth * 0.45);
    float3 seaNight = look.nightEnamel.xyz * (0.75 + 0.25 * viewCosine) * (1.0 - 0.3 * lineCore * lineFade);
    float3 seaColor = mix(seaNight, seaDay, daylight);

    float landDiffuse = saturate((dot(landNormal, sun) + 0.25) / 1.25);
    float3 silver = mix(look.silverShade.xyz, look.silver.xyz, landDiffuse);
    silver *= 1.0 - 0.28 * engraving;
    float facetSpecular = pow(saturate(dot(landNormal, halfway)), 60.0) * 0.55 * facetFade;
    float3 landDay = silver + look.sunray.xyz * facetSpecular * sunUp;
    landDay += repeaterStudio(reflect(direction, landNormal), uniforms, look) * 0.12;
    landDay = mix(landDay, landDay * look.twilight.xyz * 1.5, warmth * 0.5);
    float3 landNight = look.nightSilver.xyz * (0.6 + 0.4 * viewCosine) * (1.0 - 0.3 * engraving);
    float3 landColor = mix(landNight, landDay, daylight);

    float3 color = mix(seaColor, landColor, land);

    float wireLit = saturate(dot(wireNormal, sun) * 0.75 + 0.25);
    float wireSpecular = pow(saturate(dot(wireNormal, halfway)), 40.0) * sunUp;
    float3 wireDay = mix(look.goldShade.xyz, look.gold.xyz, wireLit) + look.sunray.xyz * wireSpecular * 0.8;
    float3 wireNight = look.goldShade.xyz * 0.35;
    color = mix(color, mix(wireNight, wireDay, daylight), wire);

    color += look.lume.xyz * lumeLevel * nightGate * (wire + 0.85 * smoothstep(0.15, 0.6, lights));

    if (active) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
        color += look.gold.xyz * popGlint;
    }
    color = mix(color, color * 0.82, saturate(loupeEdge * 2.0) * 0.4);
    color += look.sunray.xyz * loupeEdge * 0.35;

    color += look.silver.xyz * pow(1.0 - viewCosine, 3.0) * look.rimLight * mix(0.6, 1.0, daylight);
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 repeaterBackground(FullscreenVertex in [[stage_in]],
                                  constant GlobeUniforms &uniforms [[buffer(0)]],
                                  constant RepeaterLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float3 disk = globeDisk(uniforms);
    float2 offset = pixel - disk.xy;
    float radius = length(offset);
    float reach = radius / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = mix(look.backdrop.xyz, look.backdropShade.xyz, smoothstep(0.15, 1.0, length(screen)) * 0.7);

    float3 eye = uniforms.cameraPosition.xyz;
    float yaw = atan2(eye.x, eye.z);
    float theta = atan2(offset.y, offset.x);
    float rayPhase = theta / (2.0 * M_PI_F) * look.sunrayLines + 0.35 * sin(reach * 7.0);
    float rayDensity = fwidth(rayPhase);
    float rayDistance = abs(fract(rayPhase) - 0.5) * 2.0;
    float ray = (1.0 - smoothstep(0.35 - rayDensity, 0.35 + rayDensity, rayDistance)) * (1.0 - smoothstep(0.3, 0.6, rayDensity));
    float outside = smoothstep(1.0, 1.06, reach);
    color *= 1.0 - 0.045 * ray * outside;
    float sheen = pow(abs(cos(theta - yaw)), 6.0) * look.sunraySheen;
    color = mix(color, look.sunray.xyz, sheen * outside * (0.6 + 0.4 * ray));

    float ringRadius = look.chapterRing * disk.z;
    float trackWidth = 0.045 * disk.z;
    float lineWidth = max(fwidth(radius), 1e-4);
    float inner = 1.0 - smoothstep(lineWidth * 0.6, lineWidth * 1.6, abs(radius - ringRadius));
    float outer = 1.0 - smoothstep(lineWidth * 0.6, lineWidth * 1.6, abs(radius - ringRadius - trackWidth));
    float minute = theta / (2.0 * M_PI_F) * 60.0;
    float minuteDistance = abs(fract(minute + 0.5) - 0.5);
    float tickWidth = max(fwidth(minute), 1e-4);
    float tick = 1.0 - smoothstep(tickWidth * 0.6, tickWidth * 1.6, minuteDistance);
    float inTrack = step(ringRadius, radius) * step(radius, ringRadius + trackWidth);
    float hour = theta / (2.0 * M_PI_F) * 12.0;
    float hourDistance = abs(fract(hour + 0.5) - 0.5) * 2.0 * M_PI_F / 12.0 * radius;
    float batonStart = ringRadius + trackWidth * 1.6;
    float batonEnd = batonStart + 0.09 * disk.z;
    float batonHalf = 0.012 * disk.z;
    float baton = (1.0 - smoothstep(batonHalf - lineWidth, batonHalf + lineWidth, hourDistance)) * step(batonStart, radius) * step(radius, batonEnd);
    float batonShade = saturate(0.5 + 0.5 * cos(theta - yaw - 0.8));
    float printed = max(max(inner, outer), tick * inTrack);
    color = mix(color, look.ink.xyz, printed * 0.75);
    color = mix(color, mix(look.goldShade.xyz, look.gold.xyz, batonShade), baton);

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
