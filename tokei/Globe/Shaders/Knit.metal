#include "GlobeShared.h"

struct KnitLook {
    float4 backdrop;
    float4 feltShade;
    float4 fiber;
    float4 indigo;
    float4 indigoDeep;
    float4 oatmeal;
    float4 cream;
    float4 rust;
    float4 mustard;
    float4 forest;
    float4 floss;
    float4 nightTint;
    float4 knot;
    float4 sheen;
    float4 twilight;
    float4 wood;
    float rowHeight;
    float stitchWidth;
    float sectors;
    float legWidth;
    float legTilt;
    float plyFrequency;
    float plyContrast;
    float fuzzScale;
    float fuzzStrength;
    float sheenRoughness;
    float sheenStrength;
    float motifBand;
    float knotCell;
    float knotRadius;
    float knotGlow;
    float stretch;
    float pressDepth;
    float pucker;
    float buttonRadius;
    float buttonHeight;
    float patternSize;
    float patternTurns;
    float patternStrength;
    float terminatorWidth;
    float wrap;
    float reserved1;
    float reserved2;
    float reserved3;
};

constant ushort knitSnowflake[7] = { 0x08, 0x1C, 0x2A, 0x77, 0x2A, 0x1C, 0x08 };
constant ushort knitPeerie[5] = { 0x04, 0x0E, 0x1F, 0x0E, 0x04 };
constant ushort knitDiamond[7] = { 0x08, 0x1C, 0x3E, 0x7F, 0x3E, 0x1C, 0x08 };

struct KnitCell {
    float2 offset;
    float3 random;
    float3 shape;
    float present;
};

struct KnitStitch {
    float height;
    float along;
    float across;
};

static float knitNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float lowerNear = mix(hash33(cell).x, hash33(cell + float3(1.0, 0.0, 0.0)).x, t.x);
    float lowerFar = mix(hash33(cell + float3(0.0, 1.0, 0.0)).x, hash33(cell + float3(1.0, 1.0, 0.0)).x, t.x);
    float upperNear = mix(hash33(cell + float3(0.0, 0.0, 1.0)).x, hash33(cell + float3(1.0, 0.0, 1.0)).x, t.x);
    float upperFar = mix(hash33(cell + float3(0.0, 1.0, 1.0)).x, hash33(cell + float3(1.0, 1.0, 1.0)).x, t.x);
    return mix(mix(lowerNear, lowerFar, t.y), mix(upperNear, upperFar, t.y), t.z);
}

static KnitCell knitCell(float2 uv, float cosLatitude, float cell, float seed, float spread) {
    float latitude = (0.5 - uv.y) * 180.0;
    float band = (latitude + 90.0) / cell;
    float row = floor(band);
    float rowLatitude = (row + 0.5) * cell - 90.0;
    float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / cell), 1.0);
    float along = fract(uv.x) * columns;
    float column = floor(along);
    KnitCell result;
    result.random = hash33(float3(column, row, seed));
    result.shape = hash33(float3(row + 0.5, column + 0.5, seed + 3.0));
    float2 spot = 0.5 - spread * 0.5 + spread * result.random.yz;
    float cellWidth = 360.0 * cosLatitude / columns;
    result.offset = float2((fract(along) - spot.x) * cellWidth, (band - row - spot.y) * cell);
    result.present = 1.0;
    return result;
}

static KnitStitch knitStitch(float u, float v, constant KnitLook &look) {
    KnitStitch result;
    result.height = 0.0;
    result.along = 0.0;
    result.across = 0.0;
    float halfWidth = look.legWidth;
    float halfLength = 0.55;
    float2 centers[2] = { float2(-0.22, 0.5), float2(0.22, 0.5) };
    float tilts[2] = { look.legTilt, -look.legTilt };
    for (int i = 0; i < 2; i++) {
        float2 d = float2(u, v) - centers[i];
        float cosine = cos(tilts[i]);
        float sine = sin(tilts[i]);
        float2 local = float2(d.x * cosine - d.y * sine, d.x * sine + d.y * cosine);
        float2 rho = float2(local.x / halfWidth, local.y / halfLength);
        float radius = dot(rho, rho);
        if (radius < 1.0) {
            float dome = sqrt(1.0 - radius);
            if (dome > result.height) {
                result.height = dome;
                result.along = local.y / halfLength;
                result.across = local.x / halfWidth;
            }
        }
    }
    return result;
}

static float3 knitBump(float3 surfacePosition, float3 normal, float height) {
    float3 dpdx = dfdx(surfacePosition);
    float3 dpdy = dfdy(surfacePosition);
    float3 r1 = cross(dpdy, normal);
    float3 r2 = cross(normal, dpdx);
    float det = dot(dpdx, r1);
    return normalize(abs(det) * normal - sign(det) * (r1 * dfdx(height) + r2 * dfdy(height)));
}

fragment half4 knitFragment(MeshFragmentIn in [[stage_in]],
                            constant GlobeUniforms &uniforms [[buffer(0)]],
                            constant KnitLook &look [[buffer(1)]],
                            constant EffectUniforms &effects [[buffer(2)]],
                            texture2d<float> lightsTexture [[texture(1)]],
                            texture2d<float> coastTexture [[texture(2)]],
                            texture2d<float> reliefTexture [[texture(3)]],
                            texture2d<float> markTexture [[texture(6)]],
                            sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    float pixelAngle = max(max(length(dfdx(nG)), length(dfdy(nG))), 1e-5);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float viewCosine = saturate(dot(nG, view));

    float3 pK = nG;
    if (effectsActive(effects)) {
        float wP = effectWeight(nG, effects.dent.xyz, effects.radii.x) * saturate(effects.dent.w / look.pressDepth);
        pK = normalize(mix(effects.dent.xyz, nG, 1.0 / (1.0 + look.stretch * wP)));
        float wB = effectWeight(nG, effects.bump.xyz, effects.radii.y * 1.5) * saturate(effects.bump.w / look.buttonHeight);
        pK = normalize(mix(effects.bump.xyz, pK, 1.0 + look.pucker * wB));
    }

    float latitude = asin(clamp(pK.y, -1.0, 1.0)) * (180.0 / M_PI_F);
    float longitude = atan2(pK.x, pK.z) * (180.0 / M_PI_F);
    float row = floor((latitude + 90.0) / look.rowHeight);
    float rowLat = (row + 0.5) * look.rowHeight - 90.0;
    float sectorSize = 360.0 / look.sectors;
    float sector = floor((longitude + 180.0) / sectorSize);
    float rowHeightRadians = look.rowHeight * M_PI_F / 180.0;
    float stitchesPerSector = max(floor(360.0 / look.sectors * cos(rowLat * M_PI_F / 180.0) / look.stitchWidth + 0.5), 1.0);
    float fraction = ((longitude + 180.0) - sector * sectorSize) / sectorSize;
    float column = floor(fraction * stitchesPerSector);
    float u = fraction * stitchesPerSector - column - 0.5;
    float v = (latitude + 90.0 - row * look.rowHeight) / look.rowHeight;

    KnitStitch stitch = knitStitch(u, v, look);
    float amplitude = stitch.height * rowHeightRadians * 0.25;
    float detail = smoothstep(3.0, 6.0, rowHeightRadians / pixelAngle);
    float3 stitchNormal = knitBump(in.spherePosition, nG, amplitude);
    float3 n = normalize(nM + (stitchNormal - nG) * detail);

    float ply = 0.5 + 0.5 * sin(2.0 * M_PI_F * look.plyFrequency * stitch.along + 4.0 * stitch.across);
    float plyMod = mix(1.0, 1.0 + look.plyContrast * (ply * 2.0 - 1.0), detail);
    float gap = 1.0 - smoothstep(0.0, 0.4, stitch.height);

    float stitchLon = sector * sectorSize + (column + 0.5) * sectorSize / stitchesPerSector - 180.0;
    float2 stitchUV = float2(stitchLon / 360.0 + 0.5, 0.5 - rowLat / 180.0);
    float stitchCoast = coastTexture.sample(surfaceSampler, stitchUV, level(0.0)).r;
    float landAmount = smoothstep(-0.3, 0.3, stitchCoast);
    float waveRow = step(11.0, fmod(row, 12.0));
    float3 seaYarn = mix(look.indigo.xyz, look.oatmeal.xyz, 0.25 * waveRow);
    float3 yarn = mix(seaYarn, look.oatmeal.xyz, landAmount);

    float band = floor(row / look.motifBand);
    float inMotifBand = step(1.0, fmod(band, 2.0));
    float absRowLat = abs(rowLat);
    if (landAmount > 0.0 && inMotifBand > 0.0) {
        float bandRow = fmod(row, look.motifBand);
        if (absRowLat > 60.0) {
            float bitColumn = fmod(column, 7.0);
            float bit = float((knitSnowflake[int(bandRow)] >> int(bitColumn)) & 1);
            yarn = mix(yarn, look.forest.xyz, bit);
        } else if (absRowLat > 23.0) {
            float bitColumn = fmod(column, 5.0);
            float bit = float((knitPeerie[int(fmod(bandRow, 5.0))] >> int(bitColumn)) & 1);
            yarn = mix(yarn, look.rust.xyz, bit);
        } else {
            float bitColumn = fmod(column, 7.0);
            float bit = float((knitDiamond[int(bandRow)] >> int(bitColumn)) & 1);
            yarn = mix(yarn, look.mustard.xyz, bit);
        }
    }

    yarn *= plyMod;
    yarn *= 1.0 - 0.55 * gap * detail;

    MarkTap mark = markTap(markTexture, surfaceSampler, coordinates.uv, gradient);
    if (mark.coverage > 0.0) {
        float roundness = 0.75 + 0.25 * sqrt(max(1.0 - mark.phase * mark.phase, 0.0));
        yarn = mix(yarn, look.floss.xyz, mark.coverage * roundness);
    }

    if (effectsActive(effects) && effects.bump.w > 0.0) {
        float3 bumpAxis = normalize(effects.bump.xyz);
        float radius = look.buttonRadius * saturate(effects.bump.w / look.buttonHeight);
        float3 helper = abs(bumpAxis.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
        float3 east = normalize(cross(helper, bumpAxis));
        float3 north = cross(bumpAxis, east);
        float3 offset = nG - bumpAxis * dot(nG, bumpAxis);
        float2 local = float2(dot(offset, east), dot(offset, north));
        float distance = length(local);
        float disc = 1.0 - smoothstep(radius - pixelAngle * 0.5, radius + pixelAngle * 0.5, distance);
        if (disc > 0.0) {
            float angle = atan2(local.y, local.x);
            float grain = 0.5 + 0.5 * sin(angle * 5.0 + distance * 120.0);
            float rim = smoothstep(radius * 0.8, radius, distance);
            float3 woodColor = look.wood.xyz * (0.75 + 0.5 * grain);
            woodColor = mix(woodColor, look.wood.xyz * 1.3, rim);
            float holes = 0.0;
            for (int hi = 0; hi < 4; hi++) {
                float hx = (hi < 2 ? -0.28 : 0.28) * radius;
                float hy = ((hi % 2) == 0 ? -0.28 : 0.28) * radius;
                float holeRadius = 0.09 * radius;
                float holeDistance = length(local - float2(hx, hy));
                holes = max(holes, 1.0 - smoothstep(holeRadius - pixelAngle, holeRadius + pixelAngle, holeDistance));
            }
            woodColor = mix(woodColor, look.backdrop.xyz * 0.25, holes);
            float lineWidth = 0.05 * radius;
            float diagonalA = abs(local.x - local.y) * 0.70710678;
            float diagonalB = abs(local.x + local.y) * 0.70710678;
            float threadLine = max(
                1.0 - smoothstep(lineWidth * 0.5 - pixelAngle, lineWidth * 0.5 + pixelAngle, diagonalA),
                1.0 - smoothstep(lineWidth * 0.5 - pixelAngle, lineWidth * 0.5 + pixelAngle, diagonalB)
            );
            woodColor = mix(woodColor, look.floss.xyz, threadLine);
            yarn = mix(yarn, woodColor, disc);
        }
    }

    float diffuse = saturate((dot(n, sun) + look.wrap) / (1.0 + look.wrap));
    float3 halfVector = normalize(sun + view);
    float nh = saturate(dot(n, halfVector));
    float sinThetaH2 = 1.0 - nh * nh;
    float sinThetaH = sqrt(max(sinThetaH2, 0.0));
    float charlie = (2.0 + 1.0 / look.sheenRoughness) * pow(sinThetaH, 1.0 / look.sheenRoughness) / (2.0 * M_PI_F);
    float noL = saturate(dot(n, sun));
    float noV = saturate(dot(n, view));
    float visibility = 1.0 / (4.0 * max(noL + noV - noL * noV, 0.05));
    float3 sheenColor = look.sheen.xyz * (charlie * visibility) * look.sheenStrength * daylight;

    float fluff = effectsActive(effects) ? saturate(effects.radii.w) : 1.0;
    float fuzz = knitNoise(pK / look.fuzzScale);
    yarn += look.fiber.xyz * (fuzz * pow(1.0 - viewCosine, 2.0) * look.fuzzStrength * fluff);

    float3 day = yarn * diffuse + sheenColor;
    float3 night = yarn * mix(float3(1.0), look.nightTint.xyz, 1.0 - daylight);
    float3 color = mix(night, day, daylight);

    float twilightBand = 1.0 - smoothstep(0.0, look.terminatorWidth * 1.5, abs(muG));
    color += look.twilight.xyz * twilightBand * 0.3 * yarn;

    if (nightGate > 0.0) {
        float knotLat = asin(clamp(pK.y, -1.0, 1.0));
        float knotLon = atan2(pK.x, pK.z);
        float2 knotUV = float2(knotLon / (2.0 * M_PI_F) + 0.5, 0.5 - knotLat / M_PI_F);
        float cosLat = max(length(pK.xz), 1e-4);
        KnitCell site = knitCell(knotUV, cosLat, look.knotCell, 31.0, 0.0);
        float2 centerUV = knotUV - float2(site.offset.x / 360.0, -site.offset.y / 180.0);
        float knotLights = lightsTexture.sample(surfaceSampler, centerUV, level(0.0)).r;
        if (knotLights > 0.25) {
            float radius = look.knotRadius * look.knotCell;
            float knotDistance = length(site.offset);
            float coverage = 1.0 - smoothstep(radius * 0.7, radius, knotDistance);
            float knotR = knotDistance / max(radius, 1e-5);
            float knotAngle = atan2(site.offset.y, site.offset.x);
            float spiral = 0.5 + 0.5 * sin(6.0 * knotAngle + 20.0 * knotR);
            float dome = sqrt(max(1.0 - knotR * knotR, 0.0));
            color += look.knot.xyz * (coverage * dome * spiral * look.knotGlow * nightGate);
        }
    }

    if (effectsActive(effects)) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 knitBackground(FullscreenVertex in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant KnitLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 base = mix(look.backdrop.xyz, look.feltShade.xyz, smoothstep(0.15, 0.95, length(screen)) * 0.6);

    float3 eye = uniforms.cameraPosition.xyz;
    float eyeDistance = length(eye);
    float pointScale = uniforms.viewport.x / 402.0;
    float cell = look.patternSize * pointScale * pow(3.85 / max(eyeDistance, 1.0), 0.2);
    float yaw = atan2(eye.x, eye.z);
    float pitch = asin(clamp(eye.y / max(eyeDistance, 1e-4), -1.0, 1.0));
    float2 drifted = pixel + float2(-yaw, pitch) * cell * look.patternTurns / M_PI_F;
    float2 motif = float2(drifted.x / cell, drifted.y / (cell * 0.8));
    float row = floor(motif.y);
    float column = floor(motif.x);
    KnitStitch stitch = knitStitch(fract(motif.x) - 0.5, 1.0 - fract(motif.y), look);

    float stripe = step(7.0, fmod(row + 1000.0, 9.0));
    float3 yarn = mix(base, look.feltShade.xyz * 0.9, stripe * 0.6);
    yarn *= 0.94 + 0.12 * hash33(float3(column, row, 13.0)).x;
    float ply = 0.5 + 0.5 * sin(2.0 * M_PI_F * look.plyFrequency * stitch.along + 4.0 * stitch.across);
    float lit = 0.55 + 0.45 * stitch.height - 0.12 * stitch.across * stitch.height;
    float3 knitted = yarn * lit * (1.0 + look.plyContrast * (ply * 2.0 - 1.0) * stitch.height);
    float gap = 1.0 - smoothstep(0.0, 0.35, stitch.height);
    knitted = mix(knitted, base * 0.5, gap * 0.65);
    float fuzz = knitNoise(float3(pixel / (pointScale * 1.4), 5.0));
    knitted *= 1.0 + (fuzz - 0.5) * 0.08;

    float detail = smoothstep(4.0, 8.0, cell / max(fwidth(drifted.x), 1e-4) * 0.25);
    float open = smoothstep(1.02, 1.3, reach);
    float3 color = mix(base, knitted, look.patternStrength * detail * mix(0.6, 1.0, open));
    color = mix(color, base * 0.85, 0.3 * exp(-max(reach - 1.0, 0.0) * 6.0));
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
