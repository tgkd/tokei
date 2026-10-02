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
    float4 bladeCool;
    float4 bladeStraw;
    float4 clover;
    float4 cloverMark;
    float4 cloverBloom;
    float4 leaf;
    float4 white;
    float4 butter;
    float4 rose;
    float4 poppy;
    float4 violet;
    float4 sky;
    float4 coral;
    float4 magenta;
    float4 plum;
    float4 cornflower;
    float4 indigo;
    float4 lavender;
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
    float grassLean;
    float grassCurl;
    float patchCell;
    float cloverChance;
    float meadowChance;
    float clusterCell;
    float clusterChance;
    float bouquetCell;
    float bouquetChance;
    float bouquetSize;
    float bouquetDelay;
    float climateBias;
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
};

enum class GardenSpecies : int {
    spike,
    poppy,
    primrose,
    daisy,
    tulip,
    cornflower,
    starlet
};

struct GardenCell {
    float2 offset;
    float2 spot;
    float3 random;
    float3 shape;
};

struct GardenPetal {
    float edge;
    float along;
    float seam;
    float angle;
    float2 local;
};

struct GardenHabit {
    float leaves;
    float leafReach;
    float leafBreadth;
    float leafSage;
    float height;
    float spread;
};

struct GardenGrass {
    float blades;
    float height;
    float width;
    float curl;
    float seeds;
    float flowers;
    float2 lean;
    float3 deep;
    float3 tip;
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

static GardenPetal gardenPetal(float2 p, float count, float inner, float reach, float breadth) {
    float sector = 2.0 * M_PI_F / count;
    float angle = atan2(p.y, p.x);
    float a = angle - sector * round(angle / sector);
    float r = length(p);
    float semi = max(0.5 * reach, 1e-3);
    float width = max(0.5 * breadth, 1e-3);
    GardenPetal petal;
    petal.angle = angle;
    petal.local = float2(r * cos(a), r * sin(a));
    float2 q = float2((petal.local.x - inner - semi) / semi, petal.local.y / width);
    petal.edge = (length(q) - 1.0) * min(semi, width);
    petal.along = saturate(r / max(inner + reach, 1e-3));
    petal.seam = abs(a) / (0.5 * sector);
    return petal;
}

static float gardenStar(float2 p, float depth) {
    float sector = 2.0 * M_PI_F / 5.0;
    float angle = atan2(p.y, p.x);
    float a = abs(angle - sector * round(angle / sector));
    float2 offset = length(p) * float2(cos(a), sin(a)) - float2(1.0, 0.0);
    float2 side = depth * float2(cos(0.5 * sector), sin(0.5 * sector)) - float2(1.0, 0.0);
    float along = saturate(dot(offset, side) / dot(side, side));
    float inside = side.x * offset.y - side.y * offset.x;
    return length(offset - side * along) * (inside > 0.0 ? -1.0 : 1.0);
}

static float gardenTrefoil(float2 p, float size, thread float &seam) {
    float sector = 2.0 * M_PI_F / 3.0;
    float angle = atan2(p.y, p.x);
    float a = angle - sector * round(angle / sector);
    float r = length(p);
    float2 local = float2(r * cos(a), r * sin(a));
    seam = abs(a) / (0.5 * sector);
    float leaflet = length(local - float2(0.5 * size, 0.0)) - 0.44 * size;
    float notch = length(local - float2(0.97 * size, 0.0)) - 0.13 * size;
    return min(max(leaflet, -notch), r - 0.1 * size);
}

static GardenGrass gardenGrass(float3 shape, float blades, float meadow, constant GardenLook &look) {
    float3 habit = hash33(shape * 31.0 + 2.0);
    float3 tint = hash33(shape * 47.0 + 6.0);
    float lean = look.grassLean * habit.y * habit.y * (1.0 - meadow);
    float turn = habit.x * 2.0 * M_PI_F;
    float dry = max(tint.x < 0.3 ? mix(0.12, 0.4, tint.y) : 0.0, meadow * mix(0.3, 0.55, tint.y));
    float cool = tint.x > 0.72 ? mix(0.15, 0.45, tint.y) * (1.0 - meadow) : 0.0;
    float shade = mix(0.93, 1.07, habit.z);
    GardenGrass grass;
    grass.blades = blades;
    grass.height = min(mix(mix(0.84, 1.06, habit.z), mix(0.88, 0.95, habit.z), meadow), 1.06 * (1.0 - lean));
    grass.width = mix(0.17, 0.13, meadow);
    grass.curl = (tint.z - 0.5) * 2.0 * look.grassCurl;
    grass.seeds = 0.55 * meadow;
    grass.flowers = 0.25 * meadow;
    grass.lean = float2(cos(turn), sin(turn)) * lean;
    grass.deep = mix(mix(look.bladeDeep.xyz, look.bladeCool.xyz * 0.8, cool * 0.6), look.bladeStraw.xyz * 0.6, dry * 0.4) * shade;
    grass.tip = mix(mix(look.bladeTip.xyz, look.bladeCool.xyz, cool), look.bladeStraw.xyz, dry) * shade;
    return grass;
}

static void gardenTuft(thread float3 &color, float2 p, float stage, float pixel, float3 shape, GardenGrass grass, float2 shift, float shadowAmount, constant GardenLook &look) {
    float grow = gardenSpring(stage);
    float shadow = saturate(0.5 - (length(p + shift - grass.lean * 0.6) - 0.55 * grow * grass.height) / (pixel + 0.3));
    color *= 1.0 - shadowAmount * 0.8 * shadow;
    float present = step(1e-3, grow);
    float detail = 1.0 - smoothstep(0.06, 0.14, pixel);
    float2 q = p - grass.lean * length(p);
    float r = length(q);
    float sector = 2.0 * M_PI_F / grass.blades;
    float angle = atan2(q.y, q.x) - shape.y * 2.0 * M_PI_F - grass.curl * r;
    if (detail > 0.0) {
        float fineIndex = round(angle / sector - 0.5);
        float fineAngle = angle - sector * (fineIndex + 0.5);
        fineIndex -= grass.blades * floor(fineIndex / grass.blades);
        float3 fine = hash33(float3(fineIndex + 23.0, shape.z * 97.0, 8.0));
        float fineReach = mix(0.45, 0.8, fine.x) * grass.height * grow;
        float2 fineLocal = float2(r * cos(fineAngle), r * sin(fineAngle));
        float fineAlong = saturate(fineLocal.x / max(fineReach, 1e-3));
        float fineEdge = max(abs(fineLocal.y) - grass.width * 0.6 * (1.0 - fineAlong) - 0.01, fineLocal.x - fineReach);
        float3 fineColor = mix(grass.deep, grass.tip, smoothstep(0.0, 0.9, fineAlong)) * mix(0.72, 0.92, fine.y);
        color = mix(color, fineColor, saturate(0.5 - fineEdge / pixel) * present * detail);
    }
    float index = round(angle / sector);
    float a = angle - sector * index;
    index -= grass.blades * floor(index / grass.blades);
    float3 blade = hash33(float3(index + 11.0, shape.z * 97.0, 5.0));
    float reach = mix(0.7, 1.12, blade.x) * grass.height * grow;
    float2 local = float2(r * cos(a), r * sin(a));
    float along = saturate(local.x / max(reach, 1e-3));
    float halfWidth = grass.width * (1.0 - along) + 0.015;
    float edge = max(abs(local.y) - halfWidth, local.x - reach);
    float rib = 1.0 - smoothstep(0.1, 0.4, abs(local.y) / halfWidth);
    float3 bladeColor = mix(grass.deep, grass.tip, smoothstep(0.0, 0.8, along)) * mix(0.85, 1.15, blade.y) * (1.0 + 0.14 * detail * rib);
    color = mix(color, bladeColor, saturate(0.5 - edge / pixel) * present);
    float speck = (1.0 - smoothstep(0.12, 0.3, pixel)) * present;
    if (blade.z < grass.seeds) {
        float2 head = float2((local.x - reach * 0.9) / max(0.14 * grow, 1e-3), local.y / max(0.05 * grow, 1e-3));
        float headEdge = (length(head) - 1.0) * 0.05 * grow;
        float bands = smoothstep(0.2, 0.8, sin(local.x / max(grow, 1e-3) * 90.0));
        float3 headColor = look.bladeStraw.xyz * mix(0.82, 1.05, blade.y) * (1.0 - 0.18 * detail * bands);
        color = mix(color, headColor, saturate(0.5 - headEdge / pixel) * speck);
    } else if (blade.z > 1.0 - grass.flowers) {
        float late = gardenSpring(saturate(stage * 1.4 - 0.4));
        float bloom = length(local - float2(reach + 0.03 * late, 0.0)) - 0.09 * late;
        float3 bloomColor = blade.y < 0.35 ? look.butter.xyz : (blade.y < 0.65 ? look.white.xyz : (blade.y < 0.85 ? look.sky.xyz : look.rose.xyz));
        float heart = saturate(0.5 - (bloom + 0.055 * late) / pixel) * detail;
        color = mix(color, mix(bloomColor, look.eye.xyz, heart), saturate(0.5 - bloom / pixel) * speck * step(1e-3, late));
    }
}

static void gardenLeaflets(thread float3 &color, float2 p, float size, float pixel, float detail, float shade, constant GardenLook &look) {
    float seam;
    float edge = gardenTrefoil(p, size, seam);
    float r = length(p) / max(size, 1e-3);
    float mark = (1.0 - smoothstep(0.04, 0.09, abs(r - 0.45))) * (1.0 - seam) * detail;
    float3 tint = look.clover.xyz * shade * mix(0.82, 1.08, saturate(r)) * (1.0 - 0.25 * smoothstep(0.8, 1.0, seam)) * (1.0 - 0.2 * smoothstep(-0.05 * size, 0.0, edge));
    color = mix(color, mix(tint, look.cloverMark.xyz, mark * 0.55), saturate(0.5 - edge / pixel) * step(1e-3, size));
}

static void gardenClover(thread float3 &color, float2 p, float stage, float pixel, float3 shape, float2 shift, float shadowAmount, constant GardenLook &look) {
    float grow = gardenSpring(stage);
    float detail = 1.0 - smoothstep(0.06, 0.14, pixel);
    float shadow = saturate(0.5 - (length(p + shift * 0.6) - 0.85 * grow) / (pixel + 0.3));
    color *= 1.0 - shadowAmount * 0.6 * shadow;
    float count = 4.0 + floor(shape.x * 2.0);
    float sector = 2.0 * M_PI_F / count;
    float spin = shape.y * 2.0 * M_PI_F;
    float slot = round((atan2(p.y, p.x) - spin) / sector);
    float3 leaf = hash33(float3(slot - count * floor(slot / count) + 3.0, shape.z * 61.0, 9.0));
    float turn = slot * sector + spin;
    float unfurl = gardenSpring(saturate(stage * 1.3 - leaf.x * 0.3));
    float2 ring = gardenTurn(p - float2(cos(turn), sin(turn)) * 0.6 * grow, turn + leaf.y * 2.0);
    bool bloom = leaf.z < 0.25;
    if (!bloom) {
        gardenLeaflets(color, ring, 0.36 * unfurl, pixel, detail, mix(0.88, 1.04, leaf.y), look);
    }
    gardenLeaflets(color, gardenTurn(p, shape.z * 6.2831853), 0.42 * grow, pixel, detail, 1.0, look);
    if (bloom) {
        float head = length(ring) - 0.2 * unfurl;
        float florets = smoothstep(0.2, 0.9, sin(length(ring) / max(unfurl, 1e-3) * 80.0));
        float3 headColor = mix(look.cloverBloom.xyz, look.rose.xyz, step(0.5, leaf.y) * 0.5) * mix(1.05, 0.8, smoothstep(-0.08, 0.0, head)) * (1.0 - 0.14 * detail * florets);
        color = mix(color, headColor, saturate(0.5 - head / pixel) * step(1e-3, unfurl));
    }
}

static void gardenSpikes(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float detail, float3 shape, float pick, constant GardenLook &look) {
    float3 petalColor = pick < 0.4 ? look.lavender.xyz : (pick < 0.58 ? look.violet.xyz : (pick < 0.74 ? look.poppy.xyz : (pick < 0.88 ? look.rose.xyz : look.white.xyz)));
    float3 baseColor = pick < 0.58 ? look.indigo.xyz : petalColor * 0.55;
    float3 budColor = mix(look.leaf.xyz, look.sage.xyz, 0.5);
    float sector = 2.0 * M_PI_F / (3.0 + floor(shape.x * 3.0));
    float r = length(q);
    float angle = atan2(q.y, q.x) - (shape.z - 0.5) * 0.9 * r;
    float a = angle - sector * round(angle / sector);
    float2 local = float2(r * cos(a), r * sin(a));
    float grow = max(swell, 0.6 * bud);
    float present = step(0.01, bud);
    float stem = max(abs(local.y) - 0.03, local.x - 0.36 * grow);
    color = mix(color, budColor * 0.85, saturate(0.5 - stem / pixel) * present);
    float start = 0.3 * grow;
    float span = 0.66 * grow;
    float t = saturate((local.x - start) / max(span, 1e-3));
    float bead = 2.0 * fract(t * 5.0) - 1.0;
    float plump = sqrt(saturate(1.0 - bead * bead));
    float halfWidth = mix(0.15, 0.04, t) * grow * (1.0 - 0.35 * detail * (1.0 - plump));
    float edge = max(abs(local.y) - halfWidth, max(start - local.x, local.x - start - span));
    float blossom = smoothstep(t - 0.15, t + 0.05, open * 1.2);
    float3 tint = mix(baseColor, mix(petalColor, look.white.xyz, 0.2), t) * mix(0.92, 0.8 + 0.3 * plump, detail);
    tint = mix(budColor, tint, blossom) * (1.0 - 0.2 * smoothstep(-0.05, 0.0, edge));
    color = mix(color, tint, saturate(0.5 - edge / pixel) * present);
}

static void gardenPoppy(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float detail, float3 shape, float pick, constant GardenLook &look) {
    float3 petalColor = pick < 0.4 ? look.poppy.xyz : (pick < 0.6 ? look.coral.xyz : (pick < 0.72 ? look.white.xyz : (pick < 0.86 ? look.butter.xyz : look.magenta.xyz)));
    float3 blotchColor = pick < 0.86 ? look.eyeDark.xyz : look.plum.xyz;
    float blotch = pick < 0.6 || pick >= 0.86 ? 0.75 : 0.0;
    float3 eyeColor = pick >= 0.72 && pick < 0.86 ? mix(look.leaf.xyz, look.butter.xyz, 0.35) : blotchColor;
    GardenPetal petal = gardenPetal(q, 4.0, 0.0, swell, 1.15 * swell);
    float edge = petal.edge + 0.03 * swell * petal.along * sin(petal.angle * 22.0 + shape.z * 6.2831853);
    float cover = saturate(0.5 - edge / pixel) * saturate(open * 6.0);
    float3 tint = mix(petalColor * mix(0.8, 1.06, petal.along), blotchColor, blotch * (1.0 - smoothstep(0.22, 0.42, petal.along)));
    tint *= 1.0 - 0.07 * detail * smoothstep(0.4, 1.0, sin(petal.angle * 46.0));
    tint *= (1.0 - 0.22 * smoothstep(0.75, 1.0, petal.seam)) * (1.0 - 0.18 * smoothstep(-0.1, 0.0, edge));
    color = mix(color, tint, cover);
    float r = length(q);
    float stamens = (1.0 - smoothstep(0.025, 0.05, abs(r - 0.27 * swell))) * smoothstep(0.2, 0.6, sin(petal.angle * 26.0)) * detail * open;
    color = mix(color, look.eyeDark.xyz * 0.8, stamens * cover);
    float eye = r - mix(0.3 * bud, 0.2, open);
    float eyeCover = saturate(0.5 - eye / pixel) * step(0.01, bud);
    float rays = smoothstep(0.55, 0.95, cos(petal.angle * 8.0)) * (1.0 - smoothstep(0.08, 0.18, r)) * detail * open;
    float3 eyeTint = mix(mix(look.leaf.xyz, petalColor, 0.55), eyeColor, open) * mix(1.08, 0.82, smoothstep(-0.1, 0.0, eye));
    color = mix(color, mix(eyeTint, mix(look.leaf.xyz, look.white.xyz, 0.35), rays * 0.6), eyeCover);
}

static void gardenPrimrose(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float pick, constant GardenLook &look) {
    float3 petalColor = pick < 0.2 ? look.coral.xyz : (pick < 0.4 ? look.butter.xyz : (pick < 0.58 ? look.rose.xyz : (pick < 0.74 ? look.magenta.xyz : (pick < 0.88 ? look.white.xyz : look.sky.xyz))));
    float3 eyeColor = pick >= 0.2 && pick < 0.4 ? look.coral.xyz : look.eye.xyz;
    GardenPetal petal = gardenPetal(q, 5.0, 0.0, swell, 0.82 * swell);
    float edge = max(petal.edge, 0.14 * swell - length(petal.local - float2(swell, 0.0)));
    float cover = saturate(0.5 - edge / pixel) * saturate(open * 6.0);
    float3 tint = mix(petalColor, look.white.xyz, 0.3 * (1.0 - smoothstep(0.2, 0.45, petal.along))) * mix(0.8, 1.06, petal.along);
    tint *= (1.0 - 0.18 * smoothstep(0.7, 1.0, petal.seam)) * (1.0 - 0.22 * smoothstep(-0.1, 0.0, edge));
    color = mix(color, tint, cover);
    float eye = length(q) - mix(0.3 * bud, 0.18, open);
    float eyeCover = saturate(0.5 - eye / pixel) * step(0.01, bud);
    float3 eyeTint = mix(mix(look.leaf.xyz, petalColor, 0.55), eyeColor, open) * mix(1.08, 0.82, smoothstep(-0.1, 0.0, eye));
    color = mix(color, eyeTint, eyeCover);
}

static void gardenDaisy(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float detail, float3 shape, float pick, float2 sun, constant GardenLook &look) {
    float3 petalColor = pick < 0.62 ? look.white.xyz : (pick < 0.76 ? look.butter.xyz : (pick < 0.88 ? look.lavender.xyz : look.rose.xyz));
    float3 eyeColor = pick >= 0.62 && pick < 0.76 ? look.eyeDark.xyz : look.eye.xyz;
    float tipped = pick >= 0.45 && pick < 0.62 ? 0.7 : 0.0;
    GardenPetal petal = gardenPetal(q, 16.0 + floor(shape.x * 5.0), 0.15 * swell, 0.85 * swell, 0.2 * swell);
    float cover = saturate(0.5 - petal.edge / pixel) * saturate(open * 6.0);
    float3 tint = mix(petalColor, look.rose.xyz, tipped * smoothstep(0.65, 1.0, petal.along)) * mix(0.8, 1.06, petal.along);
    tint *= (1.0 - 0.18 * smoothstep(0.7, 1.0, petal.seam)) * (1.0 - 0.22 * smoothstep(-0.1, 0.0, petal.edge));
    color = mix(color, tint, cover);
    float r = length(q);
    float eye = r - mix(0.3 * bud, 0.3, open);
    float eyeCover = saturate(0.5 - eye / pixel) * step(0.01, bud);
    float florets = smoothstep(0.2, 0.8, sin(r * 70.0 + petal.angle * 8.0) * sin(r * 70.0 - petal.angle * 13.0));
    float3 eyeTint = mix(mix(look.leaf.xyz, petalColor, 0.55), eyeColor, open) * mix(1.08, 0.82, smoothstep(-0.1, 0.0, eye));
    eyeTint *= (1.0 + 0.5 * dot(q, sun)) * (1.0 - 0.2 * florets * detail * open);
    color = mix(color, eyeTint, eyeCover);
}

static void gardenTulip(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float detail, float pick, float2 sun, constant GardenLook &look) {
    float3 petalColor = pick < 0.2 ? look.poppy.xyz : (pick < 0.32 ? look.coral.xyz : (pick < 0.46 ? look.butter.xyz : (pick < 0.6 ? look.rose.xyz : (pick < 0.72 ? look.magenta.xyz : (pick < 0.82 ? look.plum.xyz : (pick < 0.92 ? look.white.xyz : look.violet.xyz))))));
    float cup = max(0.6 * bud, swell);
    float present = step(0.01, bud);
    float3 tint = mix(mix(look.leaf.xyz, petalColor, 0.45), petalColor, smoothstep(0.0, 0.5, open));
    GardenPetal inner = gardenPetal(gardenTurn(q, M_PI_F / 3.0), 3.0, 0.0, 0.8 * cup, 0.95 * cup);
    color = mix(color, tint * mix(0.55, 0.85, inner.along), saturate(0.5 - inner.edge / pixel) * present);
    GardenPetal outer = gardenPetal(q, 3.0, 0.0, 0.95 * cup, 1.15 * cup);
    float3 shell = tint * mix(0.72, 1.08, outer.along) * (1.0 + 0.25 * dot(q, sun));
    shell *= (1.0 - 0.2 * smoothstep(0.7, 1.0, outer.seam)) * (1.0 - 0.15 * smoothstep(-0.08, 0.0, outer.edge));
    shell = mix(shell, look.white.xyz, 0.18 * detail * smoothstep(0.8, 0.98, outer.along));
    color = mix(color, shell, saturate(0.5 - outer.edge / pixel) * present);
    float r = length(q);
    float opening = step(0.01, open);
    float throat = r - 0.3 * open * (1.0 - 0.18 * cos(3.0 * outer.angle));
    float3 well = mix(tint * 0.5, look.eyeDark.xyz, 0.45) * mix(0.7, 1.0, saturate(r / max(0.3 * open, 1e-3)));
    color = mix(color, well, saturate(0.5 - throat / pixel) * opening);
    color = mix(color, look.eyeDark.xyz * 0.7, saturate(0.5 - (r - 0.07 * open) / pixel) * detail * opening);
}

static void gardenCornflower(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float detail, float3 shape, float pick, constant GardenLook &look) {
    float3 petalColor = pick < 0.55 ? look.cornflower.xyz : (pick < 0.68 ? look.violet.xyz : (pick < 0.8 ? look.rose.xyz : (pick < 0.9 ? look.white.xyz : look.plum.xyz)));
    float3 heartColor = pick < 0.55 || (pick >= 0.8 && pick < 0.9) ? look.indigo.xyz : look.plum.xyz * 0.7;
    float sector = 2.0 * M_PI_F / (7.0 + floor(shape.x * 3.0));
    float angle = atan2(q.y, q.x);
    float a = angle - sector * round(angle / sector);
    float r = length(q);
    float2 local = float2(r * cos(a), r * sin(a));
    float t = saturate((local.x - 0.12 * swell) / max(0.78 * swell, 1e-3));
    float halfWidth = mix(0.05, 0.2, t) * swell;
    float teeth = abs(fract(local.y / max(halfWidth, 1e-3) * 1.6 + 0.5) - 0.5) * 2.0;
    float edge = max(abs(local.y) - halfWidth, local.x - 0.9 * swell + 0.08 * swell * teeth * mix(0.3, 1.0, detail));
    float3 tint = petalColor * mix(0.68, 1.08, t) * (1.0 - 0.18 * detail * (1.0 - smoothstep(0.0, 0.035, abs(local.y))));
    tint *= 1.0 - 0.2 * smoothstep(-0.06, 0.0, edge);
    color = mix(color, tint, saturate(0.5 - edge / pixel) * saturate(open * 6.0));
    float heart = r - mix(0.3 * bud, 0.25, open);
    float speckle = smoothstep(0.4, 0.9, sin(q.x * 48.0) * sin(q.y * 48.0)) * detail * open;
    float3 heartTint = mix(mix(look.leaf.xyz, petalColor, 0.5), heartColor, open) * mix(1.1, 0.8, smoothstep(-0.1, 0.0, heart));
    color = mix(color, mix(heartTint, petalColor * 0.8, speckle * 0.5), saturate(0.5 - heart / pixel) * step(0.01, bud));
}

static void gardenStarlet(thread float3 &color, float2 p, float size, float bud, float open, float pixel, float detail, float3 petalColor, constant GardenLook &look) {
    float scale = max(size, 1e-3);
    float2 s = p / scale;
    float starPixel = pixel / scale;
    float present = step(1e-3, size);
    float r = length(s);
    float star = gardenStar(s, 0.5) - 0.12;
    float3 tint = mix(petalColor, look.white.xyz, 0.5 * detail * (1.0 - smoothstep(0.3, 0.42, r))) * mix(0.82, 1.06, saturate(r)) * (1.0 - 0.2 * smoothstep(-0.12, 0.0, star));
    color = mix(color, tint, saturate(0.5 - star / starPixel) * saturate(open * 6.0) * present);
    float eye = r - mix(0.45 * bud, 0.2, open);
    float3 eyeTint = mix(mix(look.leaf.xyz, petalColor, 0.5), look.eye.xyz, open);
    color = mix(color, eyeTint, saturate(0.5 - eye / starPixel) * step(0.01, bud) * present);
}

static void gardenStarlets(thread float3 &color, float2 q, float bud, float open, float swell, float pixel, float detail, float3 shape, float pick, constant GardenLook &look) {
    float3 petalColor = pick < 0.4 ? look.sky.xyz : (pick < 0.62 ? look.white.xyz : (pick < 0.82 ? look.rose.xyz : look.lavender.xyz));
    float count = 5.0 + floor(shape.x * 2.0);
    float sector = 2.0 * M_PI_F / count;
    float turn = sector * round(atan2(q.y, q.x) / sector);
    float spread = max(swell, 0.6 * bud);
    float2 ring = gardenTurn(q - float2(cos(turn), sin(turn)) * 0.58 * spread, turn + shape.z * 4.0);
    gardenStarlet(color, ring, 1.5 / count * spread, bud, open, pixel, detail, petalColor, look);
    gardenStarlet(color, gardenTurn(q, shape.z * 6.2831853), 0.34 * spread, bud, open, pixel, detail, petalColor, look);
}

static GardenHabit gardenHabit(GardenSpecies species) {
    if (species == GardenSpecies::spike) {
        return GardenHabit{4.0, 0.8, 0.16, 0.7, 1.3, 0.6};
    }
    if (species == GardenSpecies::poppy) {
        return GardenHabit{2.0, 1.05, 0.45, 0.4, 1.2, 0.9};
    }
    if (species == GardenSpecies::primrose) {
        return GardenHabit{4.0, 1.08, 0.6, 0.0, 0.8, 0.85};
    }
    if (species == GardenSpecies::daisy) {
        return GardenHabit{2.0, 1.05, 0.4, 0.0, 1.0, 0.85};
    }
    if (species == GardenSpecies::tulip) {
        return GardenHabit{2.0, 1.1, 0.5, 0.45, 1.3, 0.75};
    }
    if (species == GardenSpecies::cornflower) {
        return GardenHabit{3.0, 1.0, 0.2, 0.6, 1.15, 0.8};
    }
    return GardenHabit{4.0, 0.85, 0.34, 0.15, 0.85, 0.9};
}

static GardenSpecies gardenSpecies(float roll, float climate, float bias) {
    return static_cast<GardenSpecies>(min(int((roll * (1.0 - bias) + climate * bias) * 7.0), 6));
}

static void gardenFlower(thread float3 &color, float2 p, float stage, float pixel, float3 shape, GardenSpecies species, float pick, float2 shift, float2 light, float shadowAmount, constant GardenLook &look) {
    float bud = smoothstep(0.0, 0.4, stage);
    float open = saturate((stage - 0.2) / 0.8);
    float swell = gardenSpring(open);
    float spin = shape.y * 2.0 * M_PI_F;
    float detail = 1.0 - smoothstep(0.05, 0.14, pixel);
    GardenHabit habit = gardenHabit(species);

    float shadow = saturate(0.5 - (length(p + shift * habit.height) - habit.spread * max(swell, 0.5 * bud)) / (pixel + 0.3));
    color *= 1.0 - shadowAmount * shadow;

    float2 leafPoint = gardenTurn(p, spin + 1.3);
    GardenPetal leaf = gardenPetal(leafPoint, habit.leaves, 0.08, habit.leafReach * bud, habit.leafBreadth * bud);
    float leafCover = saturate(0.5 - leaf.edge / pixel) * step(0.01, bud);
    float3 leafColor = mix(look.leaf.xyz, look.sage.xyz, habit.leafSage) * mix(0.75, 1.1, saturate(length(leafPoint)));
    color = mix(color, leafColor, leafCover);

    float turn = spin + (1.0 - open) * 0.9;
    float2 q = gardenTurn(p, turn);
    float2 sun = gardenTurn(light, turn);
    if (species == GardenSpecies::spike) {
        gardenSpikes(color, q, bud, open, swell, pixel, detail, shape, pick, look);
    } else if (species == GardenSpecies::poppy) {
        gardenPoppy(color, q, bud, open, swell, pixel, detail, shape, pick, look);
    } else if (species == GardenSpecies::primrose) {
        gardenPrimrose(color, q, bud, open, swell, pixel, pick, look);
    } else if (species == GardenSpecies::daisy) {
        gardenDaisy(color, q, bud, open, swell, pixel, detail, shape, pick, sun, look);
    } else if (species == GardenSpecies::tulip) {
        gardenTulip(color, q, bud, open, swell, pixel, detail, pick, sun, look);
    } else if (species == GardenSpecies::cornflower) {
        gardenCornflower(color, q, bud, open, swell, pixel, detail, shape, pick, look);
    } else {
        gardenStarlets(color, q, bud, open, swell, pixel, detail, shape, pick, look);
    }
}

static void gardenBouquet(thread float3 &color, float2 p, float2 times, float clock, float delay, float pixel, float3 random, int flowers, float climate, float2 shift, float2 light, float shadowAmount, constant GardenLook &look) {
    float clump = gardenAge(times, clock, delay, look);
    if (clump > 0.0 && length(p) < 0.88 + length(shift) * 0.75 + pixel) {
        gardenTuft(color, p / 0.75, clump, pixel / 0.75, random, gardenGrass(random, 12.0 + floor(random.z * 7.0), 0.0, look), shift, shadowAmount, look);
    }
    float3 mixture = hash33(random * 23.0 + 5.0);
    int first = static_cast<int>(gardenSpecies(mixture.x, climate, look.climateBias));
    int second = 1 + int(mixture.y * 6.0);
    int third = 1 + int(mixture.z * 5.0);
    third += third >= second ? 1 : 0;
    int kinds = flowers > 4 ? 3 : (flowers > 3 || mixture.z > 0.55 ? 2 : 1);
    float turn = random.x * 2.0 * M_PI_F;
    for (int index = 0; index < flowers; index++) {
        float order = float(index) / float(flowers);
        float3 place = hash33(random * 53.0 + float(index) * 7.31);
        float angle = turn + order * 2.4 * M_PI_F + (place.x - 0.5) * 0.7;
        float reach = mix(0.5, 0.1, order) + (place.y - 0.5) * 0.1;
        float size = mix(0.32, 0.46, place.z);
        float2 q = (p - float2(cos(angle), sin(angle)) * reach) / size;
        float itemPixel = pixel / size;
        if (length(q) > 1.2 + length(shift) * 1.3 + itemPixel) {
            continue;
        }
        float age = gardenAge(times, clock, delay + 0.1 + look.bouquetDelay * order + 0.08 * place.x, look);
        if (age <= 0.0) {
            continue;
        }
        float3 pick = hash33(place * 17.0 + 3.0);
        int offset = kinds == 1 || order + 0.35 * (pick.z - 0.5) > 0.45 ? 0 : (kinds == 3 && pick.y > 0.5 ? third : second);
        GardenSpecies species = static_cast<GardenSpecies>((first + offset) % 7);
        gardenFlower(color, q, age, itemPixel, pick, species, fract(random.y + (pick.x - 0.5) * 0.3), shift, light, shadowAmount, look);
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
                        float2 light,
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
    float bound = variety == 0 ? 1.22 + length(shift) * 0.4 : 1.15 + length(shift) * 0.6;
    if (length(p) > bound + pixel) {
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
        float age = gardenAge(times, clock, delay, look);
        float patch = hash33(float3(floor(cell.spot * float2(360.0, 180.0) / look.patchCell), 13.0)).x;
        if (patch < look.cloverChance && random.x < 0.7) {
            gardenClover(color, p, age, pixel, random, shift, shadowAmount, look);
            return;
        }
        float meadow = patch > 1.0 - look.meadowChance && random.x < 0.75 ? 1.0 : 0.0;
        float blades = mix(5.0 + floor(random.z * 7.0), 9.0 + floor(random.z * 5.0), meadow);
        gardenTuft(color, p, age, pixel, random, gardenGrass(random, blades, meadow, look), shift, shadowAmount, look);
        return;
    }
    float climate = saturate((abs(90.0 - cell.spot.y * 180.0) - 12.0) / 46.0);
    int flowers = variety == 1 ? 2 + int(random.z * 2.0) : 4 + int(random.z * 3.0);
    gardenBouquet(color, p, times, clock, delay, pixel, random, flowers, climate, shift, light, shadowAmount, look);
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
            gardenPlant(ground, 0, look.grassCell, look.grassChance, 0.3, 11.0, coordinates.uv, cosLatitude, footprint, clock, shift, light * daylight, shadowAmount, bloomTexture, coastTexture, surfaceSampler, look);
            gardenPlant(ground, 1, look.clusterCell, look.clusterChance, look.bouquetSize, 23.0, coordinates.uv, cosLatitude, footprint, clock, shift, light * daylight, shadowAmount, bloomTexture, coastTexture, surfaceSampler, look);
            gardenPlant(ground, 2, look.bouquetCell, look.bouquetChance, look.bouquetSize, 37.0, coordinates.uv, cosLatitude, footprint, clock, shift, light * daylight, shadowAmount, bloomTexture, coastTexture, surfaceSampler, look);
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
