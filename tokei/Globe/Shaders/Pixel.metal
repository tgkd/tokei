#include "GlobeShared.h"

struct PixelLook {
    float4 backdrop;
    float4 haze;
    float4 starDim;
    float4 star;
    float4 starBright;
    float4 halo;
    float4 haloDeep;
    float4 outline;
    float4 seaDeep;
    float4 seaOpen;
    float4 seaShelf;
    float4 seaShallow;
    float4 foam;
    float4 grassLight;
    float4 grass;
    float4 grassShade;
    float4 forestShade;
    float4 sand;
    float4 sandShade;
    float4 snow;
    float4 snowShade;
    float4 rock;
    float4 rockShade;
    float4 rockLight;
    float4 duskLand;
    float4 duskSea;
    float4 nightLand;
    float4 nightSea;
    float4 nightCoast;
    float4 cityDim;
    float4 city;
    float4 cityCore;
    float4 sparkle;
    float4 sparkleEdge;
    float shallowWidth;
    float shelfWidth;
    float openWidth;
    float duskPixels;
    float lightHigh;
    float slopeShade;
    float ditherBand;
    float reliefShade;
    float cityCell;
    float cityThreshold;
    float cityBright;
    float sparkleCount;
    float sparkleReach;
    float starCells;
    float starChance;
    float waveCell;
    float waveChance;
    float forestLevel;
    float sandLevel;
    float snowLevel;
    float rockLevel;
    float peakLevel;
    float polarRockLevel;
    float polarPeakLevel;
    float snowLatitudeLow;
    float snowLatitudeHigh;
    float capLevel;
    float capRise;
};

constant float pixelBayerMatrix[16] = {0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0};

static float pixelBayer(float2 pixel) {
    uint2 cell = uint2(floor(pixel)) & 3u;
    return (pixelBayerMatrix[cell.y * 4u + cell.x] + 0.5) / 16.0;
}

static float2 pixelScreen(float3 world, constant GlobeUniforms &uniforms) {
    float3 offset = world - uniforms.cameraPosition.xyz;
    float depth = max(dot(offset, uniforms.cameraForward.xyz), 1e-4);
    float focal = uniforms.viewport.z;
    return float2(uniforms.principal.x + focal * dot(offset, uniforms.cameraRight.xyz) / depth,
                  uniforms.principal.y - focal * dot(offset, uniforms.cameraUp.xyz) / depth);
}

static float3 pixelWorld(float3 direction, float radius, constant EffectUniforms &effects) {
    float3 point = direction * radius;
    return effectsActive(effects) ? effectShape(effects) * point : point;
}

static bool pixelFacing(float3 world, constant GlobeUniforms &uniforms) {
    return dot(normalize(world), uniforms.cameraPosition.xyz - world) > 0.0;
}

static float3 pixelDirection(float latitude, float longitude) {
    float phi = latitude * M_PI_F / 180.0;
    float lambda = longitude * M_PI_F / 180.0;
    return float3(cos(phi) * sin(lambda), sin(phi), cos(phi) * cos(lambda));
}

static float3 pixelRamp(float3 shade, float3 base, float3 light, float toShade, float toLight, float threshold) {
    if (toShade > threshold) {
        return shade;
    }
    if (toLight > threshold) {
        return light;
    }
    return base;
}

static float pixelCity(float3 nG, float radius, float2 pixel, texture2d<float> lightsTexture, sampler surfaceSampler,
                       constant PixelLook &look, constant GlobeUniforms &uniforms, constant EffectUniforms &effects) {
    float size = look.cityCell;
    float latitude = asin(clamp(nG.y, -1.0, 1.0)) * 180.0 / M_PI_F;
    float longitude = atan2(nG.x, nG.z) * 180.0 / M_PI_F;
    float rows = floor(180.0 / size);
    float row = floor((latitude + 90.0) / size);
    float lod = max(log2(size * float(lightsTexture.get_width()) / 360.0) - 1.0, 0.0);
    float best = 0.0;
    for (int dr = -1; dr <= 1; dr++) {
        float r = row + float(dr);
        if (r < 0.0 || r >= rows) {
            continue;
        }
        float rowLatitude = (r + 0.5) * size - 90.0;
        float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / size), 1.0);
        float column = floor((longitude + 180.0) / 360.0 * columns);
        for (int dc = -1; dc <= 1; dc++) {
            float c = column + float(dc);
            c -= columns * floor(c / columns);
            float3 random = hash33(float3(c, r, 41.0));
            float pointLatitude = (r + 0.2 + 0.6 * random.x) * size - 90.0;
            float pointLongitude = (c + 0.2 + 0.6 * random.y) / columns * 360.0 - 180.0;
            float2 uv = float2(pointLongitude / 360.0 + 0.5, 0.5 - pointLatitude / 180.0);
            float light = lightsTexture.sample(surfaceSampler, uv, level(lod)).r;
            if (light < look.cityThreshold * (0.55 + 0.9 * random.z)) {
                continue;
            }
            float3 world = pixelWorld(pixelDirection(pointLatitude, pointLongitude), radius, effects);
            if (!pixelFacing(world, uniforms)) {
                continue;
            }
            if (all(floor(pixelScreen(world, uniforms)) == floor(pixel))) {
                best = max(best, light);
            }
        }
    }
    return best;
}

static bool pixelWave(float3 nG, float2 pixel, texture2d<float> coastTexture, sampler surfaceSampler,
                      constant PixelLook &look, constant GlobeUniforms &uniforms, constant EffectUniforms &effects) {
    float size = look.waveCell;
    float latitude = asin(clamp(nG.y, -1.0, 1.0)) * 180.0 / M_PI_F;
    float longitude = atan2(nG.x, nG.z) * 180.0 / M_PI_F;
    float rows = floor(180.0 / size);
    float row = floor((latitude + 90.0) / size);
    float2 cellPixel = floor(pixel);
    for (int dr = -1; dr <= 1; dr++) {
        float r = row + float(dr);
        if (r < 0.0 || r >= rows) {
            continue;
        }
        float rowLatitude = (r + 0.5) * size - 90.0;
        float columns = max(floor(360.0 * cos(rowLatitude * M_PI_F / 180.0) / size), 1.0);
        float column = floor((longitude + 180.0) / 360.0 * columns);
        for (int dc = -1; dc <= 1; dc++) {
            float c = column + float(dc);
            c -= columns * floor(c / columns);
            float3 random = hash33(float3(c, r, 73.0));
            if (random.z > look.waveChance) {
                continue;
            }
            float pointLatitude = (r + 0.2 + 0.6 * random.x) * size - 90.0;
            float pointLongitude = (c + 0.2 + 0.6 * random.y) / columns * 360.0 - 180.0;
            float2 uv = float2(pointLongitude / 360.0 + 0.5, 0.5 - pointLatitude / 180.0);
            if (coastTexture.sample(surfaceSampler, uv, level(2.0)).r > -look.openWidth) {
                continue;
            }
            float3 world = pixelWorld(pixelDirection(pointLatitude, pointLongitude), 1.0, effects);
            if (dot(normalize(world), normalize(uniforms.cameraPosition.xyz - world)) < 0.35) {
                continue;
            }
            float2 offset = cellPixel - floor(pixelScreen(world, uniforms));
            if ((offset.y == 0.0 && abs(offset.x) == 1.0) || (offset.y == -1.0 && offset.x == 0.0)) {
                return true;
            }
        }
    }
    return false;
}

static float3 pixelSparkle(float2 pixel, float3 origin, float age, float radius, constant PixelLook &look,
                           constant GlobeUniforms &uniforms, constant EffectUniforms &effects) {
    float3 tangent = normalize(cross(abs(origin.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0), origin));
    float3 bitangent = cross(origin, tangent);
    float spread = look.sparkleReach * (1.0 - exp(-age * 4.5));
    float frame = floor(age * 16.0);
    float2 cellPixel = floor(pixel);
    float result = 0.0;
    float core = 0.0;
    float rim = 0.0;
    int count = int(look.sparkleCount);
    for (int index = -1; index < count; index++) {
        float3 direction = origin;
        float phase = frame;
        if (index >= 0) {
            float3 random = hash33(float3(float(index), origin.x * 91.0, origin.z * 57.0));
            float angle = 2.0 * M_PI_F * (float(index) + 0.35 * random.x) / float(count);
            float reach = spread * mix(0.7, 1.15, random.y);
            direction = normalize(origin * cos(reach) + (tangent * cos(angle) + bitangent * sin(angle)) * sin(reach));
            phase = frame - floor(random.z * 3.0) - 1.0;
        } else if (frame > 8.0) {
            continue;
        }
        if (phase < 0.0 || phase > 13.0) {
            continue;
        }
        float3 world = pixelWorld(direction, radius, effects);
        if (!pixelFacing(world, uniforms)) {
            continue;
        }
        float2 offset = cellPixel - floor(pixelScreen(world, uniforms));
        float2 span = abs(offset);
        float arm = phase < 2.0 ? 0.0 : (phase < 5.0 ? 1.0 : (phase < 8.0 ? 2.0 : (phase < 11.0 ? 1.0 : 0.0)));
        bool diagonal = phase >= 8.0 && phase < 11.0;
        if (index < 0) {
            arm = 3.0 - floor(phase / 3.0);
            diagonal = false;
        }
        float near = min(span.x, span.y);
        float far = max(span.x, span.y);
        if (span.x == 0.0 && span.y == 0.0) {
            core = 1.0;
        } else if (!diagonal && near == 0.0 && far <= arm) {
            result = 1.0;
        } else if (diagonal && span.x == span.y && span.x <= arm) {
            result = 1.0;
        } else if (!diagonal && ((near == 1.0 && far <= arm) || (near == 0.0 && far == arm + 1.0))) {
            rim = 1.0;
        } else if (diagonal && abs(span.x - span.y) == 1.0 && far <= arm + 1.0) {
            rim = 1.0;
        }
    }
    return float3(result, core, rim);
}

fragment half4 pixelFragment(MeshFragmentIn in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant PixelLook &look [[buffer(1)]],
                             constant EffectUniforms &effects [[buffer(2)]],
                             texture2d<float> dayTexture [[texture(0)]],
                             texture2d<float> lightsTexture [[texture(1)]],
                             texture2d<float> coastTexture [[texture(2)]],
                             texture2d<float> reliefTexture [[texture(3)]],
                             sampler surfaceSampler [[sampler(0)]]) {
    float2 pixel = in.position.xy;
    float threshold = pixelBayer(pixel);
    float3 sun = uniforms.sunDirection.xyz;
    float3 nG = normalize(in.spherePosition);
    float radius = length(in.spherePosition);
    SurfaceCoordinates coordinates = surfaceCoordinates(nG);
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float4 normalHeight = reliefTexture.sample(surfaceSampler, coordinates.uv, gradient);
    float coast = coastTexture.sample(surfaceSampler, coordinates.uv, gradient).r;
    float3 ground = dayTexture.sample(surfaceSampler, coordinates.uv, gradient).rgb;
    float coastStep = max(fwidth(coast), 1e-4);
    float muG = dot(nG, sun);
    float duskWidth = clamp(fwidth(muG) * look.duskPixels, 0.01, 0.2);

    bool land = coast > 0.0;
    float normalLengthSquared = dot(normalHeight.xyz, normalHeight.xyz);
    float3 nM = land && normalLengthSquared > 1e-8 ? normalHeight.xyz * rsqrt(normalLengthSquared) : nG;
    float hollow = 0.0;
    if (effectsActive(effects)) {
        float3 slope;
        effectOffset(nG, effects, slope);
        nM = normalize(mix(nG, nM, effects.radii.w) - slope);
        hollow = saturate(effects.state.z * effects.dent.w * effectWeight(nG, effects.dent.xyz, effects.radii.x));
    }
    float slope = dot(nM, sun) - dot(nG, sun);
    float toShade = max(-slope > look.slopeShade ? 1.0 : 0.0, saturate((duskWidth * 3.0 - muG) / (duskWidth * 1.5)));
    toShade = max(toShade, hollow);
    float toLight = saturate((muG + look.reliefShade * slope - look.lightHigh) / look.ditherBand + 0.5) * (1.0 - hollow);

    float3 day;
    float3 dusk;
    float3 night;
    if (land) {
        float3 tone = pow(saturate(ground), float3(1.0 / 2.2));
        float brightness = dot(tone, float3(0.299, 0.587, 0.114));
        float snowy = smoothstep(look.snowLevel - 0.06, look.snowLevel + 0.06, min(tone.r, min(tone.g, tone.b)));
        float sandy = smoothstep(-0.015, 0.035, tone.r - tone.g) * smoothstep(look.sandLevel - 0.06, look.sandLevel + 0.06, brightness);
        float forest = 1.0 - smoothstep(look.forestLevel - 0.05, look.forestLevel + 0.05, brightness);
        float3 shade = look.grassShade.xyz;
        float3 base = look.grass.xyz;
        float3 light = look.grassLight.xyz;
        if (snowy > 0.5) {
            shade = look.snowShade.xyz;
            base = look.snow.xyz;
            light = look.snow.xyz;
        } else if (sandy > 0.5) {
            shade = look.sandShade.xyz;
            base = look.sand.xyz;
            light = look.sand.xyz;
        } else if (forest > 0.5) {
            shade = look.forestShade.xyz;
            base = look.grassShade.xyz;
            light = look.grass.xyz;
        }
        float elevation = saturate(normalHeight.w);
        float regional = saturate(reliefTexture.sample(surfaceSampler, coordinates.uv, level(look.capLevel)).w);
        float polar = smoothstep(look.snowLatitudeLow, look.snowLatitudeHigh, abs(asin(clamp(nG.y, -1.0, 1.0))));
        float rockLine = mix(look.rockLevel, look.polarRockLevel, polar);
        float snowLine = mix(look.peakLevel, look.polarPeakLevel, polar);
        bool capped = elevation > 0.97 || (elevation > snowLine && elevation - regional > look.capRise);
        if (capped) {
            shade = look.snowShade.xyz;
            base = look.snow.xyz;
            light = look.snow.xyz;
        } else if (elevation > rockLine && snowy <= 0.5) {
            shade = look.rockShade.xyz;
            base = look.rock.xyz;
            light = look.rockLight.xyz;
        }
        bool edge = coast < coastStep;
        day = edge ? shade : pixelRamp(shade, base, light, toShade, toLight, threshold);
        dusk = look.duskLand.xyz;
        night = edge ? look.nightCoast.xyz : look.nightLand.xyz;
    } else {
        float seaward = -coast;
        day = seaward < max(look.shallowWidth, coastStep * 0.8) ? look.seaShallow.xyz
            : (seaward < look.shelfWidth ? look.seaShelf.xyz
            : (seaward < look.openWidth ? look.seaOpen.xyz : look.seaDeep.xyz));
        if (hollow > threshold) {
            day = seaward < look.shelfWidth ? look.seaOpen.xyz : look.seaDeep.xyz;
        }
        dusk = look.duskSea.xyz;
        night = look.nightSea.xyz;
    }

    float band = (muG + duskWidth) / (2.0 * duskWidth);
    float3 color;
    if (band >= 1.0) {
        color = day;
    } else if (band <= 0.0) {
        color = night;
    } else if (band > 0.5) {
        color = (band - 0.5) * 2.0 > threshold ? day : dusk;
    } else {
        color = band * 2.0 > threshold ? dusk : night;
    }

    if (!land && band >= 1.0 && -coast > look.openWidth && pixelWave(nG, pixel, coastTexture, surfaceSampler, look, uniforms, effects)) {
        color = look.seaOpen.xyz;
    }

    if (!land && band >= 1.0) {
        float3 glint = normalize(sun + normalize(uniforms.cameraPosition.xyz));
        float3 world = pixelWorld(glint, 1.0, effects);
        float2 glintUV = float2(atan2(glint.x, glint.z) / (2.0 * M_PI_F) + 0.5, 0.5 - asin(clamp(glint.y, -1.0, 1.0)) / M_PI_F);
        if (pixelFacing(world, uniforms) && coastTexture.sample(surfaceSampler, glintUV, level(2.0)).r < -0.3) {
            float2 span = abs(floor(pixel) - floor(pixelScreen(world, uniforms)));
            float distance = span.x + span.y;
            if (distance == 0.0) {
                color = look.foam.xyz;
            } else if ((span.x == 0.0 || span.y == 0.0) && distance <= 2.0) {
                color = distance < 2.0 ? look.foam.xyz : look.seaShallow.xyz;
            } else if (span.x == 1.0 && span.y == 1.0) {
                color = look.seaShallow.xyz;
            }
        }
    }

    if (land && band < 0.5) {
        float light = pixelCity(nG, radius, pixel, lightsTexture, surfaceSampler, look, uniforms, effects);
        if (light > 0.0) {
            color = light > look.cityBright ? look.cityCore.xyz : (light > look.cityThreshold * 1.6 ? look.city.xyz : look.cityDim.xyz);
        }
    }

    if (effectsActive(effects) && effects.ripple.w >= 0.0) {
        float3 sparkle = pixelSparkle(pixel, normalize(effects.ripple.xyz), effects.ripple.w, radius, look, uniforms, effects);
        if (sparkle.y > 0.0 || sparkle.x > 0.0) {
            color = look.sparkle.xyz;
        } else if (sparkle.z > 0.0) {
            color = look.sparkleEdge.xyz;
        }
    }

    if (threshold >= uniforms.principal.z) {
        color = look.backdrop.xyz;
    }
    return finishColor(color, pixel);
}

static float3 pixelStar(float3 direction, float2 pixel, constant PixelLook &look, constant GlobeUniforms &uniforms, float3 background) {
    float3 a = abs(direction);
    float2 coordinate;
    float face;
    if (a.x >= a.y && a.x >= a.z) {
        coordinate = direction.yz / a.x;
        face = direction.x > 0.0 ? 0.0 : 1.0;
    } else if (a.y >= a.z) {
        coordinate = direction.xz / a.y;
        face = direction.y > 0.0 ? 2.0 : 3.0;
    } else {
        coordinate = direction.xy / a.z;
        face = direction.z > 0.0 ? 4.0 : 5.0;
    }
    float cells = look.starCells;
    float2 cell = floor((coordinate * 0.5 + 0.5) * cells);
    float3 key = float3(cell, face * 13.0 + 7.0);
    float3 random = hash33(key);
    if (random.x > look.starChance) {
        return background;
    }
    float2 jitter = 0.3 + 0.4 * hash33(key + 17.0).xy;
    float3 center = normalize(faceDirection(face, (cell + jitter) / cells * 2.0 - 1.0));
    float depth = dot(center, uniforms.cameraForward.xyz);
    if (depth <= 0.0) {
        return background;
    }
    float focal = uniforms.viewport.z;
    float2 screen = float2(uniforms.principal.x + focal * dot(center, uniforms.cameraRight.xyz) / depth,
                           uniforms.principal.y - focal * dot(center, uniforms.cameraUp.xyz) / depth);
    float2 span = abs(floor(pixel) - floor(screen));
    float kind = random.y;
    if (kind > 0.93) {
        if (span.x == 0.0 && span.y == 0.0) {
            return look.starBright.xyz;
        }
        if ((span.x == 0.0 && span.y <= 2.0) || (span.y == 0.0 && span.x <= 2.0)) {
            return span.x + span.y > 1.0 ? look.starDim.xyz : look.star.xyz;
        }
        return background;
    }
    if (kind > 0.8) {
        if (span.x == 0.0 && span.y == 0.0) {
            return look.starBright.xyz;
        }
        if (span.x + span.y == 1.0) {
            return look.starDim.xyz;
        }
        return background;
    }
    if (span.x == 0.0 && span.y == 0.0) {
        return kind > 0.45 ? look.star.xyz : look.starDim.xyz;
    }
    return background;
}

fragment half4 pixelBackground(FullscreenVertex in [[stage_in]],
                               constant GlobeUniforms &uniforms [[buffer(0)]],
                               constant PixelLook &look [[buffer(1)]]) {
    float2 pixel = in.position.xy;
    float threshold = pixelBayer(pixel);
    float focal = uniforms.viewport.z;
    float3 disk = globeDisk(uniforms);
    float reach = length(floor(pixel) + 0.5 - disk.xy) - disk.z;
    float haze = saturate(1.0 - (reach - 2.0) / 10.0) * 0.55;
    float3 color = haze > threshold ? look.haze.xyz : look.backdrop.xyz;
    float3 direction = normalize(globeRay(pixel, focal, uniforms));
    color = pixelStar(direction, pixel, look, uniforms, color);

    float3 origin = uniforms.cameraPosition.xyz;
    float along = -dot(origin, direction);
    float3 closest = normalize(origin + direction * along);
    float sunward = dot(closest, uniforms.sunDirection.xyz);
    float3 hit = sphereHit(origin, direction, 1.0);
    if (reach < -0.5 && hit.z > 0.0) {
        float3 ground = normalize(origin + direction * hit.x);
        bool lit = dot(ground, uniforms.sunDirection.xyz) > 0.0;
        if (ground.y < -0.88) {
            color = lit ? look.snow.xyz : look.nightLand.xyz;
        } else {
            color = lit ? look.seaDeep.xyz : look.nightSea.xyz;
        }
    } else if (reach < 1.0) {
        color = look.outline.xyz;
    } else if (reach < 2.0 && sunward > -0.1) {
        color = sunward > 0.35 ? look.halo.xyz : look.haloDeep.xyz;
    } else if (reach < 4.0 && sunward > 0.2) {
        float fade = (4.0 - reach) / 2.0 * saturate(sunward * 2.0);
        color = fade > threshold ? look.haloDeep.xyz : color;
    }

    if (threshold >= uniforms.principal.z) {
        color = look.backdrop.xyz;
    }
    return finishColor(color, pixel);
}
