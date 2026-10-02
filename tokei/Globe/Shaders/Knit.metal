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
    float waveRows;
    float motifPeriod;
    float knotCell;
    float knotRadius;
    float knotGlow;
    float stretch;
    float pressDepth;
    float patternSize;
    float patternTurns;
    float patternStrength;
    float terminatorWidth;
    float wrap;
    float yarnRadius;
    float yarnDepth;
    float yarnSink;
    float plies;
    float twistFrequency;
    float twistContrast;
    float creaseShade;
    float undersideShade;
    float backingShade;
    float toneVariation;
    float nightLift;
    float pompomRadius;
    float pompomRise;
    float pompomSquash;
    float pompomStrands;
    float pompomFiber;
    float pompomCore;
    float cityRadius;
    float cityRise;
    float citySquash;
    float cityStrands;
    float cityFiber;
    float cityGate;
    float detailPixels;
    float finePixels;
    float closePixels;
    float seamMinimum;
    float seamSplit;
    float liningReach;
    float reserved1;
    float reserved2;
    float reserved3;
};

struct KnitYarnPiece {
    float4 span;
    float4 course;
    float4 yarn;
    float4 color;
};

struct KnitYarnFragmentIn {
    float4 position [[position]];
    float3 worldPosition;
    float3 rest;
    float3 normal;
    float2 strand;
    float depth;
    float3 color [[flat]];
    float2 tag [[flat]];
};

struct KnitPath {
    float3 center;
    float3 tangent;
    float3 reference;
    float radius;
    float slope;
    float depth;
};

struct KnitSite {
    float row;
    float column;
    float2 uv;
};

constant ushort knitSnowflake[3] = { 2, 1, 2 };
constant ushort knitPeerie[3] = { 1, 3, 1 };
constant ushort knitDiamond[3] = { 1, 2, 1 };
constant uint2 knitTubes[4] = { uint2(12, 4), uint2(16, 6), uint2(24, 8), uint2(32, 10) };
constant float4 knitLoop = float4(0.03, 0.25, 0.15, 0.78);

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

static float knitGoreColumns(float rowLatitude, constant KnitLook &look) {
    float narrowest = min(abs(rowLatitude) + knitLoop.w * look.rowHeight, 90.0);
    return max(floor(180.0 / look.sectors * cos(narrowest * M_PI_F / 180.0) / look.stitchWidth), 0.0);
}

static KnitSite knitSite(float3 direction, constant KnitLook &look) {
    float latitude = asin(clamp(direction.y, -1.0, 1.0)) * (180.0 / M_PI_F);
    float longitude = atan2(direction.x, direction.z) * (180.0 / M_PI_F);
    float row = floor((latitude + 90.0) / look.rowHeight);
    float rowLatitude = (row + 0.5) * look.rowHeight - 90.0;
    float goreWidth = 360.0 / look.sectors;
    float halfGore = 0.5 * goreWidth;
    float middle = (floor((longitude + 180.0) / goreWidth) + 0.5) * goreWidth - 180.0;
    float rowCosine = max(cos(rowLatitude * M_PI_F / 180.0), 1e-3);
    float columns = knitGoreColumns(rowLatitude, look);
    float across = (longitude - middle) * cos(latitude * M_PI_F / 180.0);
    float side = across < 0.0 ? -1.0 : 1.0;
    float column = floor(abs(across) / look.stitchWidth);
    float gap = 2.0 * (halfGore * rowCosine - columns * look.stitchWidth);
    bool seam = columns < 1.0 || gap >= look.seamMinimum * look.stitchWidth;
    float stitchLongitude = middle + side * (column + 0.5) * look.stitchWidth / rowCosine;
    if (!seam && column >= columns - 1.0) {
        column = columns - 1.0;
        stitchLongitude = middle + side * 0.5 * (halfGore + column * look.stitchWidth / rowCosine);
    } else if (column >= columns && gap >= look.seamSplit * look.stitchWidth) {
        column = columns;
        stitchLongitude = middle + side * 0.5 * (halfGore + column * look.stitchWidth / rowCosine);
    } else if (column >= columns) {
        column = columns;
        stitchLongitude = middle + side * halfGore;
    }
    return {row, column, float2(stitchLongitude / 360.0 + 0.5, 0.5 - rowLatitude / 180.0)};
}

static float3 knitYarnColor(float row, float column, bool land, constant KnitLook &look) {
    float waveRow = step(look.waveRows - 1.0, fmod(row, look.waveRows));
    if (!land) {
        return mix(look.indigo.xyz, look.oatmeal.xyz, 0.25 * waveRow);
    }
    float line = fmod(row, look.motifBand);
    if (fmod(floor(row / look.motifBand), 2.0) < 1.0 || line > 2.5) {
        return look.oatmeal.xyz;
    }
    float middle = abs((row - line + 1.5) * look.rowHeight - 90.0);
    int index = int(line);
    int shift = int(fmod(column, look.motifPeriod));
    float bit;
    float3 motif;
    if (middle > 60.0) {
        bit = float((knitSnowflake[index] >> shift) & 1);
        motif = look.forest.xyz;
    } else if (middle > 23.0) {
        bit = float((knitPeerie[index] >> shift) & 1);
        motif = look.rust.xyz;
    } else {
        bit = float((knitDiamond[index] >> shift) & 1);
        motif = look.mustard.xyz;
    }
    return mix(look.oatmeal.xyz, motif, bit);
}

static KnitPath knitStitchPath(KnitYarnPiece piece, float along) {
    float wiggle = piece.yarn.y > 1.5 ? 0.0 : 1.0;
    float t = M_PI_F * (2.0 * along - 1.0);
    float c1 = cos(t);
    float s1 = sin(t);
    float c2 = cos(2.0 * t);
    float s2 = sin(2.0 * t);
    float shape = t * (0.5 / M_PI_F) + wiggle * (knitLoop.x * s1 + knitLoop.y * s2);
    float shapeRate = 0.5 / M_PI_F + wiggle * (knitLoop.x * c1 + 2.0 * knitLoop.y * c2);
    float latitude = piece.course.x + piece.course.y * (knitLoop.z + knitLoop.w * c1);
    float latitudeRate = -piece.course.y * knitLoop.w * s1;
    float cosLatitude = cos(latitude);
    float sinLatitude = sin(latitude);
    float secant = 1.0 / cosLatitude;
    float spread = piece.span.w + piece.span.z * secant;
    float longitude = piece.span.x + piece.span.y * secant + shape * spread;
    float longitudeRate = (piece.span.y + shape * piece.span.z) * secant * secant * sinLatitude * latitudeRate + shapeRate * spread;
    float radial = 1.0 + piece.course.w - piece.course.z * c2;
    float radialRate = 2.0 * piece.course.z * s2;
    float cosLongitude = cos(longitude);
    float sinLongitude = sin(longitude);
    float3 up = float3(cosLatitude * sinLongitude, sinLatitude, cosLatitude * cosLongitude);
    float3 east = float3(cosLongitude, 0.0, -sinLongitude);
    float3 north = float3(-sinLatitude * sinLongitude, cosLatitude, -sinLatitude * cosLongitude);
    KnitPath path;
    path.center = up * radial;
    path.tangent = up * radialRate + radial * (north * latitudeRate + east * (cosLatitude * longitudeRate));
    path.reference = up;
    path.radius = piece.yarn.x;
    path.slope = 0.0;
    path.depth = mix(-1.0, -c2, wiggle);
    return path;
}

static KnitPath knitStrandPath(float3 root, float3 tip, float bend, float width, float twist, float along) {
    float3 axis = tip - root;
    float3 direction = normalize(axis);
    float3 helper = abs(direction.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 side = normalize(cross(direction, helper));
    float3 other = cross(direction, side);
    float turn = 2.0 * M_PI_F * twist;
    float3 bow = side * cos(turn) + other * sin(turn);
    float arc = max(sin(M_PI_F * along), 0.0);
    float swell = M_PI_F * cos(M_PI_F * along);
    KnitPath path;
    path.center = root + axis * along + bow * (bend * arc);
    path.tangent = axis + bow * (bend * swell);
    path.reference = cross(direction, bow);
    path.radius = width * pow(arc, 0.3);
    path.slope = clamp(width * 0.3 * pow(max(arc, 1e-4), -0.7) * swell / max(length(path.tangent), 1e-6), -2.5, 2.5);
    path.depth = along;
    return path;
}

static KnitPath knitCityPath(KnitYarnPiece piece, float along, float growth, constant EffectUniforms &effects) {
    float3 axis = normalize(effects.bump.xyz);
    float3 helper = abs(axis.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0);
    float3 east = normalize(cross(helper, axis));
    float3 north = cross(axis, east);
    float size = piece.yarn.x * pow(growth, 0.7);
    float rise = piece.course.z * mix(1.3, 1.0, growth);
    float3 spoke = east * piece.span.x + axis * (piece.span.y * rise) + north * piece.span.z;
    float3 center = axis * (1.0 + piece.course.w * mix(0.4, 1.0, growth));
    float3 reach = spoke * (size * piece.course.x);
    return knitStrandPath(center + reach * 0.12, center + reach, piece.span.w * size, piece.course.y * size, piece.yarn.z, along);
}

vertex KnitYarnFragmentIn knitYarnVertex(uint vertexID [[vertex_id]],
                                         uint instanceID [[instance_id]],
                                         constant GlobeUniforms &uniforms [[buffer(0)]],
                                         const device KnitYarnPiece *pieces [[buffer(1)]],
                                         constant EffectUniforms &effects [[buffer(2)]],
                                         constant SurfaceUniforms &surface [[buffer(3)]],
                                         const device uint *visible [[buffer(4)]]) {
    KnitYarnPiece piece = pieces[visible[instanceID]];
    float kind = piece.yarn.y;
    float3 viewDirection = normalize(uniforms.cameraPosition.xyz);
    float growth = 0.0;
    if (kind > 2.5) {
        bool open = piece.color.w < 0.0 ? viewDirection.y > piece.color.w : -viewDirection.y >= piece.color.w;
        growth = open && effectsActive(effects) ? saturate(effects.bump.w / piece.yarn.w) : 0.0;
        if (growth < 0.02) {
            KnitYarnFragmentIn hidden;
            hidden.position = float4(0.0, 0.0, -1.0, 1.0);
            hidden.worldPosition = float3(0.0);
            hidden.rest = float3(0.0, 1.0, 0.0);
            hidden.normal = float3(0.0, 1.0, 0.0);
            hidden.strand = float2(0.0);
            hidden.depth = 0.0;
            hidden.color = float3(0.0);
            hidden.tag = float2(0.0);
            return hidden;
        }
    }
    uint2 tube = knitTubes[min(uint(surface.clock.y), 3u)];
    uint ring = tube.y + 1u;
    float along = float(vertexID / ring) / float(tube.x);
    float angle = 2.0 * M_PI_F * float(vertexID % ring) / float(tube.y);
    bool strand = kind > 0.5 && abs(kind - 2.0) > 0.5;
    KnitPath path;
    if (kind > 2.5) {
        path = knitCityPath(piece, along, growth, effects);
    } else if (strand) {
        path = knitStrandPath(piece.span.xyz, piece.course.xyz, piece.span.w, piece.yarn.x, piece.yarn.z, along);
    } else {
        path = knitStitchPath(piece, along);
    }
    float3 tangent = normalize(path.tangent);
    float3 above = normalize(path.reference - tangent * dot(path.reference, tangent));
    float3 beside = cross(above, tangent);
    float3 around = beside * cos(angle) + above * sin(angle);
    float3 normal = normalize(around - tangent * path.slope);
    float3 rest = path.center + around * path.radius;
    float3 center = path.center;
    if (effectsActive(effects) && kind < 0.5 && piece.yarn.w > 0.0) {
        float radial = length(center);
        float3 direction = center / radial;
        float pull = effectWeight(direction, effects.dent.xyz, effects.radii.x) * max(effects.dent.w, 0.0) * piece.yarn.w;
        center = normalize(mix(effects.dent.xyz, direction, 1.0 + pull)) * radial;
    }
    float3 position = center + around * path.radius;
    if (effectsActive(effects)) {
        float3 direction = normalize(position);
        float3 slope;
        effectOffset(direction, effects, slope);
        normal += direction * (dot(normal, direction) * (1.0 / max(effects.radii.w, 0.05) - 1.0));
        normal = normalize(normalize(normal) - slope);
    }
    float3 world = surfacePlace(position, effects);

    KnitYarnFragmentIn out;
    out.position = projectToClip(world, uniforms);
    out.position.z = clamp(out.position.z, 0.0, max(out.position.w, 0.0));
    out.worldPosition = world;
    out.rest = rest;
    out.normal = normal;
    out.strand = float2(strand ? along : M_PI_F * (2.0 * along - 1.0), angle);
    out.depth = path.depth;
    out.color = piece.color.xyz;
    out.tag = float2(piece.yarn.y, piece.yarn.z);
    return out;
}

fragment half4 knitYarnFragment(KnitYarnFragmentIn in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant KnitLook &look [[buffer(1)]],
                                constant EffectUniforms &effects [[buffer(2)]],
                                texture2d<float> lightsTexture [[texture(1)]],
                                texture2d<float> markTexture [[texture(6)]],
                                sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    bool shaped = effectsActive(effects);
    float3 position = shaped ? effectUnshape(effects) * in.worldPosition : in.worldPosition;
    float3 eye = shaped ? effectUnshape(effects) * uniforms.cameraPosition.xyz : uniforms.cameraPosition.xyz;
    float3 nG = normalize(position);
    float3 view = normalize(eye - position);
    float3 sun = uniforms.sunDirection.xyz;
    float3 rest = normalize(in.rest);
    SurfaceCoordinates coordinates = surfaceCoordinates(rest);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    gradient2d glowGradient = gradient2d(coordinates.dx * 4.0, coordinates.dy * 4.0);
    float pixelAngle = max(max(length(dfdx(rest)), length(dfdy(rest))), 1e-5);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    float twistPhase = look.plies * in.strand.y + look.twistFrequency * in.strand.x;
    float twistBlur = fwidth(twistPhase);
    MarkTap mark = markTap(markTexture, surfaceSampler, coordinates.uv, gradient);
    float lights = lightsTexture.sample(surfaceSampler, coordinates.uv, glowGradient).r;
    float fiberScale = 57.2958 / look.fuzzScale;
    float fineDetail = 1.0 - smoothstep(0.35, 0.9, pixelAngle * fiberScale);
    float fibers = fineDetail > 0.0 ? knitNoise(rest * fiberScale) : 0.5;

    float3 n = normalize(in.normal);
    bool strand = in.tag.x > 0.5 && abs(in.tag.x - 2.0) > 0.5;
    float3 yarn = in.color * (1.0 + look.toneVariation * (2.0 * in.tag.y - 1.0));
    float occlusion = 1.0;
    if (strand) {
        occlusion = mix(look.pompomCore, 1.0, smoothstep(0.05, 0.8, in.depth));
        yarn *= 1.0 + (fibers - 0.5) * 0.2 * fineDetail;
    } else {
        float crease = smoothstep(-1.0, 0.6, in.depth);
        float underside = saturate(0.5 + 0.5 * dot(n, nG));
        occlusion = mix(look.creaseShade, 1.0, crease) * mix(look.undersideShade, 1.0, underside);
        float groove = 0.5 - 0.5 * cos(twistPhase);
        float twist = look.twistContrast * (1.0 - smoothstep(0.8, 2.2, twistBlur));
        yarn *= 1.0 + twist * (0.3 - groove * groove);
        yarn *= 1.0 + (fibers - 0.5) * 0.14 * fineDetail;
    }

    if (mark.coverage > 0.0) {
        float roundness = 0.75 + 0.25 * sqrt(max(1.0 - mark.phase * mark.phase, 0.0));
        yarn = mix(yarn, look.floss.xyz, mark.coverage * roundness);
    }

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float facing = saturate(dot(n, view));
    float diffuse = saturate((dot(n, sun) + look.wrap) / (1.0 + look.wrap));
    float3 halfVector = normalize(sun + view);
    float nh = saturate(dot(n, halfVector));
    float sinThetaH = sqrt(max(1.0 - nh * nh, 0.0));
    float charlie = (2.0 + 1.0 / look.sheenRoughness) * pow(sinThetaH, 1.0 / look.sheenRoughness) / (2.0 * M_PI_F);
    float noL = saturate(dot(n, sun));
    float visibility = 1.0 / (4.0 * max(noL + facing - noL * facing, 0.05));
    float3 sheenColor = look.sheen.xyz * (charlie * visibility * noL * look.sheenStrength * daylight);

    float fluff = shaped ? saturate(effects.radii.w) : 1.0;
    float rim = (1.0 - facing) * (1.0 - facing);
    float fuzz = look.fuzzStrength * fluff * (strand ? 1.6 : 1.0);
    yarn += look.fiber.xyz * (rim * fuzz * mix(0.7, 0.3 + 1.4 * fibers, fineDetail));

    float3 day = (yarn * diffuse + sheenColor) * occlusion;
    float3 night = yarn * mix(float3(1.0), look.nightTint.xyz, 1.0 - daylight) * occlusion * (1.0 - look.nightLift + look.nightLift * facing);
    float3 color = mix(night, day, daylight);

    float twilightBand = 1.0 - smoothstep(0.0, look.terminatorWidth * 1.5, abs(muG));
    color += look.twilight.xyz * twilightBand * 0.3 * yarn * occlusion;

    if (!strand && nightGate > 0.0) {
        color += look.knot.xyz * (lights * lights * 0.35 * nightGate * occlusion);
        float knotLatitude = asin(clamp(rest.y, -1.0, 1.0));
        float knotLongitude = atan2(rest.x, rest.z);
        float2 knotUV = float2(knotLongitude / (2.0 * M_PI_F) + 0.5, 0.5 - knotLatitude / M_PI_F);
        float cosLatitude = max(length(rest.xz), 1e-4);
        KnitCell site = knitCell(knotUV, cosLatitude, look.knotCell, 31.0, 0.0);
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

    if (in.tag.x > 2.5) {
        color += look.knot.xyz * (0.3 * nightGate * occlusion);
    }

    if (shaped) {
        float pressWeight = effectWeight(nG, effects.dent.xyz, effects.radii.x);
        color *= saturate(1.0 - effects.state.z * effects.dent.w * pressWeight);
    }

    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 knitFragment(MeshFragmentIn in [[stage_in]],
                            constant GlobeUniforms &uniforms [[buffer(0)]],
                            constant KnitLook &look [[buffer(1)]],
                            constant EffectUniforms &effects [[buffer(2)]],
                            texture2d<float> coastTexture [[texture(2)]],
                            texture2d<float> markTexture [[texture(6)]],
                            sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    bool shaped = effectsActive(effects);
    float pull = shaped ? effectWeight(nG, effects.dent.xyz, effects.radii.x) * max(effects.dent.w, 0.0) * look.stretch / look.pressDepth : 0.0;
    float3 pK = shaped ? normalize(mix(effects.dent.xyz, nG, 1.0 / (1.0 + pull))) : nG;
    SurfaceCoordinates coordinates = surfaceCoordinates(pK);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
    MarkTap mark = markTap(markTexture, surfaceSampler, coordinates.uv, gradient);
    KnitSite site = knitSite(pK, look);
    float coast = coastTexture.sample(surfaceSampler, site.uv, level(0.0)).r;

    float3 yarn = knitYarnColor(site.row, site.column, coast > 0.0, look) * look.backingShade;
    if (mark.coverage > 0.0) {
        yarn = mix(yarn, look.floss.xyz * look.backingShade * 1.5, mark.coverage);
    }

    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float diffuse = saturate((muG + look.wrap) / (1.0 + look.wrap));
    float3 day = yarn * diffuse;
    float3 night = yarn * mix(float3(1.0), look.nightTint.xyz, 1.0 - daylight);
    float3 color = mix(night, day, daylight);

    if (shaped) {
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
