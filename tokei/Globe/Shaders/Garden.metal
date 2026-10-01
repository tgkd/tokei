#include "GlobeShared.h"

struct GardenLook {
    float4 backdrop;
    float4 backdropShade;
    float4 backdropLight;
    float4 seaDeep;
    float4 seaOpen;
    float4 seaShallow;
    float4 seaNight;
    float4 glint;
    float4 lawnDeep;
    float4 lawn;
    float4 lawnLight;
    float4 lawnSun;
    float4 meadow;
    float4 sage;
    float4 hedge;
    float4 treeDark;
    float4 treeLight;
    float4 bush;
    float4 shore;
    float4 bladeDeep;
    float4 bladeTip;
    float4 leaf;
    float4 white;
    float4 butter;
    float4 rose;
    float4 poppy;
    float4 violet;
    float4 sky;
    float4 coral;
    float4 magenta;
    float4 eye;
    float4 eyeDark;
    float4 moon;
    float4 twilight;
    float4 cityLight;
    float wrap;
    float shallowWidth;
    float shoreWidth;
    float glintPower;
    float glintStrength;
    float lawnScale;
    float grassScale;
    float grassContrast;
    float plotSize;
    float plotWarp;
    float pathChance;
    float hedgeWidth;
    float stripeWidth;
    float stripeStrength;
    float treeCell;
    float treeChance;
    float bushCell;
    float bushChance;
    float groveLevel;
    float grassCell;
    float grassChance;
    float clusterCell;
    float clusterChance;
    float bouquetCell;
    float bouquetChance;
    float bouquetSize;
    float bouquetDelay;
    float coastMargin;
    float grow;
    float hold;
    float hide;
    float stagger;
    float shadowLength;
    float shadowStrength;
    float moonStrength;
    float terminatorWidth;
    float twilightWidth;
    float cityGlow;
    float haze;
    float dappleCells;
    float dappleStrength;
    float grain;
    float reserved1;
    float reserved2;
};

struct GardenCell {
    float2 offset;
    float2 spot;
    float3 random;
    float3 shape;
};

struct GardenBloom {
    float count;
    float inner;
    float reach;
    float breadth;
    float eye;
    float3 petal;
    float3 center;
};

static float gardenNoise(float3 p) {
    float3 cell = floor(p);
    float3 t = p - cell;
    t = t * t * (3.0 - 2.0 * t);
    float lowerNear = mix(hash33(cell).x, hash33(cell + float3(1.0, 0.0, 0.0)).x, t.x);
    float lowerFar = mix(hash33(cell + float3(0.0, 1.0, 0.0)).x, hash33(cell + float3(1.0, 1.0, 0.0)).x, t.x);
    float upperNear = mix(hash33(cell + float3(0.0, 0.0, 1.0)).x, hash33(cell + float3(1.0, 0.0, 1.0)).x, t.x);
    float upperFar = mix(hash33(cell + float3(0.0, 1.0, 1.0)).x, hash33(cell + float3(1.0, 1.0, 1.0)).x, t.x);
    return mix(mix(lowerNear, lowerFar, t.y), mix(upperNear, upperFar, t.y), t.z);
}

static GardenCell gardenCell(float2 uv, float cosLatitude, float cell, float seed, float spread) {
    float latitude = (0.5 - uv.y) * 180.0;
    float band = (latitude + 90.0) / cell;
    float row = floor(band);
    float rowLatitude = (row + 0.5) * cell - 90.0;
    float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / cell), 1.0);
    float along = fract(uv.x) * columns;
    float column = floor(along);
    GardenCell result;
    result.random = hash33(float3(column, row, seed));
    result.shape = hash33(float3(row + 0.5, column + 0.5, seed + 3.0));
    float2 spot = 0.5 - spread * 0.5 + spread * result.random.yz;
    float cellWidth = 360.0 * cosLatitude / columns;
    result.offset = float2((fract(along) - spot.x) * cellWidth, (band - row - spot.y) * cell);
    result.spot = float2((column + spot.x) / columns, 0.5 - ((row + spot.y) * cell - 90.0) / 180.0);
    return result;
}

static void gardenFields(thread float3 &ground, float2 uv, float3 nG, float cosLatitude, float footprint, constant GardenLook &look) {
    float2 warp = look.plotWarp * float2(sin(dot(nG, float3(25.1, 14.3, -21.7))) + 0.45 * sin(dot(nG, float3(-47.3, 39.9, 41.1))),
                                         sin(dot(nG, float3(-19.9, 27.7, 18.1))) + 0.45 * sin(dot(nG, float3(44.7, -42.3, 38.3))));
    float size = look.plotSize;
    float latitude = (0.5 - uv.y) * 180.0 + warp.y;
    float longitude = uv.x * 360.0 + warp.x / cosLatitude;
    float row = floor((latitude + 90.0) / size);
    float first = 1e4;
    float second = 1e4;
    float2 nearest = float2(0.0);
    float2 neighbor = float2(0.0);
    float2 nearestDelta = float2(0.0);
    for (int rowStep = -1; rowStep <= 1; rowStep++) {
        float band = row + float(rowStep);
        float columns = max(floor(360.0 * cos(((band + 0.5) * size - 90.0) * M_PI_F / 180.0) / size), 1.0);
        float column = floor(longitude / 360.0 * columns);
        for (int columnStep = -1; columnStep <= 1; columnStep++) {
            float slot = column + float(columnStep);
            float wrapped = slot - columns * floor(slot / columns);
            float3 random = hash33(float3(wrapped, band, 71.0));
            float2 delta = float2(((slot + 0.15 + 0.7 * random.x) / columns * 360.0 - longitude) * cosLatitude,
                                  (band + 0.15 + 0.7 * random.y) * size - 90.0 - latitude);
            float gap = length(delta);
            if (gap < first) {
                second = first;
                neighbor = nearest;
                first = gap;
                nearest = float2(wrapped, band);
                nearestDelta = delta;
            } else if (gap < second) {
                second = gap;
                neighbor = float2(wrapped, band);
            }
        }
    }
    float3 seed = hash33(float3(nearest, 17.0));
    float3 tint = seed.x < 0.25 ? look.lawn.xyz : (seed.x < 0.45 ? look.lawnLight.xyz : (seed.x < 0.62 ? look.meadow.xyz : (seed.x < 0.8 ? look.sage.xyz : look.lawnDeep.xyz)));
    ground = mix(ground, tint, 0.4);
    if (seed.y < 0.45) {
        float turn = seed.z * M_PI_F;
        float wave = sin(dot(-nearestDelta, float2(cos(turn), sin(turn))) / look.stripeWidth * M_PI_F);
        float strength = look.stripeStrength * (1.0 - smoothstep(0.3, 0.7, footprint / look.stripeWidth));
        ground *= mix(1.0 - strength, 1.0 + strength, smoothstep(-0.35, 0.35, wave));
    }
    float edge = (second - first) * 0.5;
    float blur = footprint * 0.75;
    bool path = hash33(float3(nearest + neighbor, 7.0)).x < look.pathChance;
    float width = path ? look.hedgeWidth * 0.7 : look.hedgeWidth;
    float line = 1.0 - smoothstep(width - blur, width + blur, edge);
    ground = mix(ground, path ? look.shore.xyz : look.hedge.xyz, line * (path ? 0.7 : 0.55));
}

static void gardenCrown(thread float3 &ground,
                        float cellSize,
                        float chance,
                        float seed,
                        float3 tint,
                        float2 uv,
                        float cosLatitude,
                        float footprint,
                        float2 shift,
                        float2 light,
                        float shadowAmount,
                        texture2d<float> coastTexture,
                        sampler surfaceSampler,
                        constant GardenLook &look) {
    GardenCell cell = gardenCell(uv, cosLatitude, cellSize, seed, 0.45);
    if (cell.random.x > chance) {
        return;
    }
    float radius = cellSize * 0.26 * mix(0.6, 1.0, cell.shape.x);
    float pixel = footprint / radius;
    float2 p = cell.offset / radius;
    if (length(p) > 1.2 + length(shift) + pixel) {
        return;
    }
    if (coastTexture.sample(surfaceSampler, cell.spot, level(0.0)).r < radius * 1.2) {
        return;
    }
    float angle = atan2(p.y, p.x);
    float rim = 1.0 + 0.05 * sin(angle * 7.0 + cell.shape.y * 6.2831853) + 0.03 * sin(angle * 11.0 + cell.shape.z * 6.2831853);
    float shadow = saturate(0.5 - (length(p + shift * 1.6) - 0.9 * rim) / (pixel + 0.35));
    ground *= 1.0 - shadowAmount * shadow * saturate(2.0 - pixel * 2.0);
    float body = length(p) - rim;
    float cover = saturate(0.5 - body / pixel);
    float lit = saturate(dot(p, light) * 0.4 + 0.85 - 0.25 * dot(p, p));
    float3 crown = mix(look.treeDark.xyz, tint, lit) * mix(0.92, 1.08, cell.shape.z);
    ground = mix(ground, crown, cover);
}

static void gardenGrove(thread float3 &ground,
                        float2 uv,
                        float cosLatitude,
                        float variety,
                        float footprint,
                        float2 shift,
                        float2 light,
                        float shadowAmount,
                        texture2d<float> coastTexture,
                        sampler surfaceSampler,
                        constant GardenLook &look) {
    float grove = 1.0 - smoothstep(look.groveLevel - 0.12, look.groveLevel, variety);
    if (grove <= 0.0) {
        return;
    }
    gardenCrown(ground, look.bushCell, look.bushChance * grove, 61.0, look.bush.xyz, uv, cosLatitude, footprint, shift * 0.6, light, shadowAmount, coastTexture, surfaceSampler, look);
    gardenCrown(ground, look.treeCell, look.treeChance * grove, 53.0, look.treeLight.xyz, uv, cosLatitude, footprint, shift, light, shadowAmount, coastTexture, surfaceSampler, look);
}

static float2 gardenTimes(texture2d<float> bloomTexture, float2 spot) {
    float2 size = float2(bloomTexture.get_width(), bloomTexture.get_height());
    uint2 texel = uint2(clamp(floor(spot * size), float2(0.0), size - 1.0));
    return bloomTexture.read(texel).rg;
}

static float gardenAge(float2 times, float clock, float delay, constant GardenLook &look) {
    float rise = saturate((clock - times.x - delay) / look.grow);
    float fall = saturate((clock - times.y - delay) / look.hide);
    return rise * (1.0 - fall);
}

static float gardenSpring(float x) {
    float t = saturate(x) - 1.0;
    return 1.0 + 2.2 * t * t * t + 1.2 * t * t;
}

static float2 gardenTurn(float2 p, float angle) {
    float2 axis = float2(cos(angle), sin(angle));
    return float2(dot(p, axis), dot(p, float2(-axis.y, axis.x)));
}

static float gardenPetals(float2 p, float count, float inner, float reach, float breadth) {
    float sector = 2.0 * M_PI_F / count;
    float angle = atan2(p.y, p.x);
    float a = angle - sector * round(angle / sector);
    float r = length(p);
    float semi = max(0.5 * reach, 1e-3);
    float width = max(0.5 * breadth, 1e-3);
    float2 q = float2((r * cos(a) - inner - semi) / semi, r * sin(a) / width);
    return (length(q) - 1.0) * min(semi, width);
}

static float3 gardenHue(float family, float pick, constant GardenLook &look) {
    if (family < 0.25) {
        return pick < 0.4 ? look.poppy.xyz : (pick < 0.7 ? look.coral.xyz : look.butter.xyz);
    }
    if (family < 0.5) {
        return pick < 0.4 ? look.violet.xyz : (pick < 0.75 ? look.sky.xyz : look.white.xyz);
    }
    if (family < 0.75) {
        return pick < 0.45 ? look.rose.xyz : (pick < 0.75 ? look.magenta.xyz : look.white.xyz);
    }
    return pick < 0.35 ? look.white.xyz : (pick < 0.65 ? look.butter.xyz : (pick < 0.85 ? look.sky.xyz : look.rose.xyz));
}

static GardenBloom gardenBloom(float kind, float3 petal, float3 eye, constant GardenLook &look) {
    if (kind < 0.3) {
        return GardenBloom{12.0, 0.16, 0.84, 0.26, 0.3, petal, eye};
    }
    if (kind < 0.6) {
        return GardenBloom{5.0, 0.0, 1.0, 0.8, 0.22, petal, eye};
    }
    if (kind < 0.8) {
        return GardenBloom{4.0, 0.0, 1.0, 1.1, 0.2, petal, look.eyeDark.xyz};
    }
    return GardenBloom{6.0, 0.08, 0.92, 0.42, 0.18, petal, eye};
}

static void gardenFlower(thread float3 &color, float2 p, float stage, float pixel, float3 shape, float2 shift, float shadowAmount, GardenBloom bloom, constant GardenLook &look) {
    float bud = smoothstep(0.0, 0.4, stage);
    float open = saturate((stage - 0.2) / 0.8);
    float swell = gardenSpring(open);
    float spin = shape.y * 2.0 * M_PI_F;

    float shadow = saturate(0.5 - (length(p + shift) - 0.85 * max(swell, 0.5 * bud)) / (pixel + 0.3));
    color *= 1.0 - shadowAmount * shadow;

    float2 leafPoint = gardenTurn(p, spin + 1.3);
    float leaf = gardenPetals(leafPoint, 2.0, 0.08, 1.05 * bud, 0.4 * bud);
    float leafCover = saturate(0.5 - leaf / pixel) * step(0.01, bud);
    color = mix(color, look.leaf.xyz * mix(0.75, 1.1, saturate(length(leafPoint))), leafCover);

    float2 q = gardenTurn(p, spin + (1.0 - open) * 0.9);
    float petal = gardenPetals(q, bloom.count, bloom.inner * swell, bloom.reach * swell, bloom.breadth * swell);
    float petalCover = saturate(0.5 - petal / pixel) * saturate(open * 6.0);
    float seam = abs(fract(atan2(q.y, q.x) * bloom.count / (2.0 * M_PI_F) + 0.5) - 0.5) * 2.0;
    float radial = saturate(length(q) / max((bloom.inner + bloom.reach) * swell, 1e-3));
    float3 petalColor = bloom.petal * mix(0.8, 1.06, radial);
    petalColor *= (1.0 - 0.18 * smoothstep(0.7, 1.0, seam)) * (1.0 - 0.22 * smoothstep(-0.1, 0.0, petal));
    color = mix(color, petalColor, petalCover);

    float eye = length(p) - mix(0.3 * bud, bloom.eye, open);
    float eyeCover = saturate(0.5 - eye / pixel) * step(0.01, bud);
    float3 eyeColor = mix(mix(look.leaf.xyz, bloom.petal, 0.55), bloom.center, open) * mix(1.08, 0.82, smoothstep(-0.1, 0.0, eye));
    color = mix(color, eyeColor, eyeCover);
}

static void gardenTuft(thread float3 &color, float2 p, float stage, float pixel, float3 shape, float blades, float2 shift, float shadowAmount, constant GardenLook &look) {
    float grow = gardenSpring(stage);
    float shadow = saturate(0.5 - (length(p + shift) - 0.55 * grow) / (pixel + 0.3));
    color *= 1.0 - shadowAmount * 0.8 * shadow;
    float sector = 2.0 * M_PI_F / blades;
    float angle = atan2(p.y, p.x) - shape.y * 2.0 * M_PI_F;
    float index = round(angle / sector);
    float a = angle - sector * index;
    float3 blade = hash33(float3(index + 11.0, shape.z * 97.0, 5.0));
    float reach = mix(0.7, 1.15, blade.x) * grow;
    float r = length(p);
    float2 local = float2(r * cos(a), r * sin(a));
    float along = saturate(local.x / max(reach, 1e-3));
    float halfWidth = 0.17 * (1.0 - along) + 0.015;
    float edge = max(abs(local.y) - halfWidth, local.x - reach);
    float cover = saturate(0.5 - edge / pixel) * step(1e-3, grow);
    float3 bladeColor = mix(look.bladeDeep.xyz, look.bladeTip.xyz, smoothstep(0.0, 0.8, along)) * mix(0.85, 1.15, blade.y);
    color = mix(color, bladeColor, cover);
}

static void gardenBouquet(thread float3 &color, float2 p, float2 times, float clock, float delay, float pixel, float3 random, int flowers, float2 shift, float shadowAmount, constant GardenLook &look) {
    float clump = gardenAge(times, clock, delay, look);
    if (clump > 0.0 && length(p) < 0.88 + length(shift) * 0.75 + pixel) {
        gardenTuft(color, p / 0.75, clump, pixel / 0.75, random, 14.0 + floor(random.z * 5.0), shift, shadowAmount, look);
    }
    float turn = random.x * 2.0 * M_PI_F;
    for (int index = 0; index < flowers; index++) {
        float order = float(index) / float(flowers);
        float3 place = hash33(random * 53.0 + float(index) * 7.31);
        float angle = turn + order * 2.4 * M_PI_F + (place.x - 0.5) * 0.7;
        float reach = mix(0.5, 0.1, order) + (place.y - 0.5) * 0.1;
        float size = mix(0.32, 0.46, place.z);
        float2 q = (p - float2(cos(angle), sin(angle)) * reach) / size;
        float itemPixel = pixel / size;
        if (length(q) > 1.2 + length(shift) + itemPixel) {
            continue;
        }
        float age = gardenAge(times, clock, delay + 0.1 + look.bouquetDelay * order + 0.08 * place.x, look);
        if (age <= 0.0) {
            continue;
        }
        float3 pick = hash33(place * 17.0 + 3.0);
        float3 eye = pick.z < 0.3 ? look.eyeDark.xyz : look.eye.xyz;
        gardenFlower(color, q, age, itemPixel, pick, shift, shadowAmount, gardenBloom(pick.y, gardenHue(random.y, pick.x, look), eye, look), look);
    }
}

static void gardenPlant(thread float3 &color,
                        int variety,
                        float cellSize,
                        float chance,
                        float size,
                        float seed,
                        float2 uv,
                        float cosLatitude,
                        float footprint,
                        float clock,
                        float2 shift,
                        float shadowAmount,
                        texture2d<float> bloomTexture,
                        texture2d<float> coastTexture,
                        sampler surfaceSampler,
                        constant GardenLook &look) {
    GardenCell cell = gardenCell(uv, cosLatitude, cellSize, seed, 0.15);
    if (cell.random.x > chance) {
        return;
    }
    float radius = cellSize * size * mix(0.85, 1.0, cell.shape.x);
    float pixel = footprint / radius;
    float2 p = cell.offset / radius;
    if (length(p) > 1.15 + length(shift) * 0.4 + pixel) {
        return;
    }
    float2 times = gardenTimes(bloomTexture, cell.spot);
    float delay = cell.shape.z * look.stagger;
    if (clock < times.x + delay || clock > times.y + delay + look.bouquetDelay + 0.2 + look.hide) {
        return;
    }
    if (coastTexture.sample(surfaceSampler, cell.spot, level(0.0)).r < radius * look.coastMargin) {
        return;
    }
    float3 random = hash33(cell.random * 41.0 + seed);
    if (variety == 0) {
        gardenTuft(color, p, gardenAge(times, clock, delay, look), pixel, random, 7.0 + floor(random.z * 3.0), shift, shadowAmount, look);
        return;
    }
    int flowers = variety == 1 ? 2 + int(random.z * 2.0) : 4 + int(random.z * 3.0);
    gardenBouquet(color, p, times, clock, delay, pixel, random, flowers, shift, shadowAmount, look);
}

fragment half4 gardenFragment(MeshFragmentIn in [[stage_in]],
                              constant GlobeUniforms &uniforms [[buffer(0)]],
                              constant GardenLook &look [[buffer(1)]],
                              constant EffectUniforms &effects [[buffer(2)]],
                              texture2d<float> lightsTexture [[texture(1)]],
                              texture2d<float> coastTexture [[texture(2)]],
                              texture2d<float> reliefTexture [[texture(3)]],
                              texture2d<float> bloomTexture [[texture(7)]],
                              sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float3 direction = normalize(in.spherePosition - effectUnshape(effects) * uniforms.cameraPosition.xyz);
    float3 view = -direction;
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    float muG = dot(nG, sun);
    float terminatorWidth = max(fwidth(muG), look.terminatorWidth);
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
    float3 nW = nG;
    float relief = saturate(normalHeight.w);
    float cosLatitude = max(length(nG.xz), 1e-3);
    float2 degrees = float2(360.0 * cosLatitude, 180.0);
    float footprint = max(max(length(coordinates.dx * degrees), length(coordinates.dy * degrees)), 1e-5);
    float daylight = smoothstep(-terminatorWidth, terminatorWidth, muG);
    float nightGate = 1.0 - smoothstep(-0.14, 0.04, muG);
    float3 east = float3(nG.z, 0.0, -nG.x) / cosLatitude;
    float3 north = cross(nG, east);

    float clock = 0.0;
    float hollow = 0.0;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope);
        nW = normalize(nG - slope - effects.wave.x * rippleSlope(nG, effects));
        relief *= effects.radii.w;
        clock = effects.state.w;
        hollow = saturate(effects.state.z * effects.dent.w * effectWeight(nG, effects.dent.xyz, effects.radii.x));
    }

    float3 ground = look.lawn.xyz;
    if (land > 0.0) {
        float2 sunTangent = float2(dot(sun, east), dot(sun, north));
        float2 light = sunTangent / max(length(sunTangent), 1e-4);
        float lean = min(length(sunTangent) / max(muG, 0.2), 2.5);
        float2 shift = light * look.shadowLength * lean * daylight;
        float shadowAmount = look.shadowStrength * daylight;
        float variety = gardenNoise(nG * look.lawnScale) * 0.65 + gardenNoise(nG * look.lawnScale * 2.7 + 7.0) * 0.35;
        float fineFade = 1.0 - smoothstep(0.25, 0.6, footprint * look.grassScale / 57.2958);
        ground = mix(look.lawnDeep.xyz, look.lawn.xyz, smoothstep(0.2, 0.55, variety));
        ground = mix(ground, look.lawnLight.xyz, smoothstep(0.5, 0.85, variety) * 0.85);
        ground = mix(ground, look.lawnSun.xyz, smoothstep(0.3, 0.9, relief) * 0.5);
        gardenFields(ground, coordinates.uv, nG, cosLatitude, footprint, look);
        gardenGrove(ground, coordinates.uv, cosLatitude, variety, footprint, shift, light, shadowAmount, coastTexture, surfaceSampler, look);
        if (fineFade > 0.0) {
            ground *= 1.0 + look.grassContrast * (gardenNoise(nG * look.grassScale + 3.0) - 0.5) * 2.0 * fineFade;
        }
        float shore = (1.0 - smoothstep(look.shoreWidth * 0.4, look.shoreWidth, coast)) * saturate(look.shoreWidth / coastWidth - 0.5);
        ground = mix(ground, look.shore.xyz, shore);
        if (clock > 0.0) {
            gardenPlant(ground, 0, look.grassCell, look.grassChance, 0.3, 11.0, coordinates.uv, cosLatitude, footprint, clock, shift, shadowAmount, bloomTexture, coastTexture, surfaceSampler, look);
            gardenPlant(ground, 1, look.clusterCell, look.clusterChance, look.bouquetSize, 23.0, coordinates.uv, cosLatitude, footprint, clock, shift, shadowAmount, bloomTexture, coastTexture, surfaceSampler, look);
            gardenPlant(ground, 2, look.bouquetCell, look.bouquetChance, look.bouquetSize, 37.0, coordinates.uv, cosLatitude, footprint, clock, shift, shadowAmount, bloomTexture, coastTexture, surfaceSampler, look);
        }
    }

    float seaward = max(-coast, 0.0);
    float shallow = exp(-seaward / look.shallowWidth);
    float3 sea = mix(look.seaDeep.xyz, look.seaOpen.xyz, exp(-seaward / (look.shallowWidth * 6.0)));
    sea = mix(sea, look.seaShallow.xyz, shallow * 0.8);

    float viewCosine = saturate(dot(nG, view));
    float diffuse = saturate((dot(nM, sun) + look.wrap) / (1.0 + look.wrap));
    float3 landDay = ground * (0.42 + 0.58 * diffuse);
    float3 seaDay = sea * mix(0.82, 1.0, saturate(muG * 3.0));
    float3 day = mix(landDay, seaDay, water) * mix(0.62, 1.0, smoothstep(0.0, 0.3, muG));
    float warmth = (1.0 - smoothstep(0.0, look.twilightWidth, muG)) * daylight;
    day = mix(day, day * look.twilight.xyz * 1.4, warmth * mix(0.5, 0.3, water));

    float moonlit = 0.12 + look.moonStrength * saturate(dot(nM, -sun) * 0.5 + 0.5);
    float3 landNight = ground * look.moon.xyz * moonlit;
    float3 seaNight = look.seaNight.xyz * (1.0 + 0.6 * shallow);
    float3 night = mix(landNight, seaNight, water);

    float3 color = mix(night, day, daylight);
    color += look.cityLight.xyz * (pow(lights, 1.5) + 0.3 * lightsHalo) * nightGate * land * look.cityGlow;

    float3 halfway = normalize(sun + view);
    color += look.glint.xyz * pow(saturate(dot(nW, halfway)), look.glintPower) * look.glintStrength * water * daylight;
    float3 moonway = normalize(view - sun);
    color += look.moon.xyz * pow(saturate(dot(nW, moonway)), look.glintPower * 0.5) * look.glintStrength * 0.25 * water * nightGate;
    float grazing = pow(1.0 - saturate(dot(nW, view)), 3.0);
    color = mix(color, mix(look.seaNight.xyz, look.backdropLight.xyz, daylight), grazing * 0.35 * water);

    color *= 1.0 - 0.6 * hollow;
    color = mix(color, mix(look.seaNight.xyz, look.backdropLight.xyz, daylight), look.haze * pow(1.0 - viewCosine, 2.5));
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}

fragment half4 gardenBackground(FullscreenVertex in [[stage_in]],
                                constant GlobeUniforms &uniforms [[buffer(0)]],
                                constant GardenLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    float3 disk = globeDisk(uniforms);
    float reach = length(pixel - disk.xy) / disk.z;
    float2 screen = (pixel - uniforms.viewport.xy * 0.5) / uniforms.viewport.y;
    float3 color = mix(look.backdropLight.xyz, look.backdrop.xyz, smoothstep(-0.45, 0.5, screen.y));
    BackdropPoint dapple = backdropPoint(direction, look.dappleCells, 3.0, focal);
    float radius = (0.3 + 0.25 * dapple.random.y) / look.dappleCells * focal;
    float spot = 1.0 - smoothstep(0.35, 1.0, length(dapple.offset) / radius);
    color = mix(color, dapple.random.x < 0.55 ? look.backdropShade.xyz : look.backdropLight.xyz, look.dappleStrength * spot);
    color = mix(color, look.backdropLight.xyz, 0.5 * exp(-max(reach - 1.0, 0.0) * 7.0));
    float grain = gardenNoise(float3(pixel * 0.35, 3.0));
    color *= 1.0 + (grain - 0.5) * look.grain;
    color = mix(look.backdrop.xyz, color, uniforms.principal.z);
    return finishColor(color, pixel);
}
