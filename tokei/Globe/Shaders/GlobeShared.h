#pragma once

#include <metal_stdlib>
using namespace metal;

#define GROUND_RADIUS 1.0

struct GlobeUniforms {
    float4 cameraPosition;
    float4 cameraRight;
    float4 cameraUp;
    float4 cameraForward;
    float4 sunDirection;
    float4 viewport;
    float4 principal;
};

struct FullscreenVertex {
    float4 position [[position]];
};

struct EffectUniforms {
    float4 shapeX;
    float4 shapeY;
    float4 shapeZ;
    float4 unshapeX;
    float4 unshapeY;
    float4 unshapeZ;
    float4 dent;
    float4 bump;
    float4 ripple;
    float4 radii;
    float4 wave;
    float4 state;
    float4 detail;
};

struct MeshFragmentIn {
    float4 position [[position]];
    float3 spherePosition;
};

struct SurfaceCoordinates {
    float2 uv;
    float2 dx;
    float2 dy;
};

struct Cellular {
    float2 cell;
    float edge;
};

static inline float safeSqrt(float value) {
    return sqrt(max(value, 0.0));
}

static inline float3 sphereHit(float3 origin, float3 direction, float radius) {
    float b = dot(origin, direction);
    float c = dot(origin, origin) - radius * radius;
    float discriminant = b * b - c;
    if (discriminant < 0.0) {
        return float3(0.0, 0.0, 0.0);
    }
    float root = sqrt(discriminant);
    return float3(-b - root, -b + root, 1.0);
}

static inline float hash12(float2 p) {
    float3 q = fract(float3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

static inline float3 hash33(float3 p) {
    p = fract(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

static inline float3 faceDirection(float face, float2 coordinate) {
    if (face < 0.5) {
        return float3(1.0, coordinate.x, coordinate.y);
    }
    if (face < 1.5) {
        return float3(-1.0, coordinate.x, coordinate.y);
    }
    if (face < 2.5) {
        return float3(coordinate.x, 1.0, coordinate.y);
    }
    if (face < 3.5) {
        return float3(coordinate.x, -1.0, coordinate.y);
    }
    if (face < 4.5) {
        return float3(coordinate.x, coordinate.y, 1.0);
    }
    return float3(coordinate.x, coordinate.y, -1.0);
}

static inline float3 stars(float3 direction, float focal) {
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
    float2 st = coordinate * 0.5 + 0.5;
    float3 color = float3(0.0);
    for (int layer = 0; layer < 2; layer++) {
        float cells = layer == 0 ? 70.0 : 170.0;
        float2 cell = floor(st * cells);
        float3 seed = float3(cell, face * 13.0 + float(layer) * 101.0);
        float3 random = hash33(seed);
        float chance = layer == 0 ? 0.30 : 0.18;
        if (random.x < chance) {
            float2 jitter = 0.2 + 0.6 * hash33(seed + 17.0).xy;
            float2 starCoordinate = (cell + jitter) / cells * 2.0 - 1.0;
            float3 starDirection = normalize(faceDirection(face, starCoordinate));
            float pixels = length(cross(direction, starDirection)) * focal;
            float magnitude = layer == 0 ? pow(random.y, 5.0) * 2.4 + 0.06 : pow(random.y, 3.0) * 0.35 + 0.03;
            float core = exp(-pixels * pixels / (2.0 * 0.55 * 0.55));
            float3 tint = mix(float3(0.72, 0.82, 1.0), float3(1.0, 0.88, 0.72), random.z);
            color += tint * magnitude * core;
        }
    }
    return color;
}

struct BackdropPoint {
    float3 random;
    float2 offset;
};

static inline BackdropPoint backdropPoint(float3 direction, float cells, float seed, float focal) {
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
    float2 cell = floor((coordinate * 0.5 + 0.5) * cells);
    float3 key = float3(cell, face * 13.0 + seed);
    float2 jitter = 0.25 + 0.5 * hash33(key + 17.0).xy;
    float3 center = normalize(faceDirection(face, (cell + jitter) / cells * 2.0 - 1.0));
    float3 east = normalize(cross(abs(center.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0), center));
    float3 north = cross(center, east);
    float3 delta = direction / max(dot(direction, center), 1e-3) - center;
    return {hash33(key), float2(dot(delta, east), dot(delta, north)) * focal};
}

static inline float3 globeDisk(constant GlobeUniforms &uniforms) {
    float distance = length(uniforms.cameraPosition.xyz);
    return float3(uniforms.principal.xy, uniforms.viewport.z / sqrt(max(distance * distance - 1.0, 1e-4)));
}

static inline float3 tonemap(float3 color) {
    const float startCompression = 0.76;
    const float desaturation = 0.15;
    float peak = max(color.r, max(color.g, color.b));
    if (peak < startCompression) {
        return color;
    }
    const float d = 1.0 - startCompression;
    float newPeak = 1.0 - d * d / (peak + d - startCompression);
    color *= newPeak / peak;
    float g = 1.0 - 1.0 / (desaturation * (peak - newPeak) + 1.0);
    return mix(color, float3(newPeak), g);
}

static inline float3 encodeSRGB(float3 color) {
    float3 c = saturate(color);
    return select(1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, c * 12.92, c <= 0.0031308);
}

static inline half4 finishColor(float3 color, float2 pixel) {
    color = encodeSRGB(tonemap(color));
    float noise = (hash12(pixel) + hash12(pixel + 71.3) - 1.0) / 255.0;
    return half4(half3(color + noise), 1.0h);
}

static inline float3 globeRay(float2 pixel, float focal, constant GlobeUniforms &uniforms) {
    return uniforms.cameraForward.xyz * focal
           + uniforms.cameraRight.xyz * (pixel.x - uniforms.principal.x)
           - uniforms.cameraUp.xyz * (pixel.y - uniforms.principal.y);
}

static inline float globeCoverage(float3 origin, float3 direction, float along, float focal) {
    float closestDistance = length(origin + direction * along);
    float edgePixels = (closestDistance - GROUND_RADIUS) * focal / max(along, 1e-3);
    return saturate(0.5 - edgePixels);
}

static inline SurfaceCoordinates surfaceCoordinates(float3 normal) {
    float longitude = atan2(normal.x, normal.z);
    float latitude = asin(clamp(normal.y, -1.0, 1.0));
    float2 uv = float2(longitude / (2.0 * M_PI_F) + 0.5, 0.5 - latitude / M_PI_F);
    float seamless = fract(uv.x + 0.5);
    float2 dx = dfdx(uv);
    float2 dy = dfdy(uv);
    float dxSeamless = dfdx(seamless);
    float dySeamless = dfdy(seamless);
    dx.x = abs(dx.x) < abs(dxSeamless) ? dx.x : dxSeamless;
    dy.x = abs(dy.x) < abs(dySeamless) ? dy.x : dySeamless;
    return {uv, dx, dy};
}

static inline float coastCoverage(float distance, float width) {
    return saturate(distance / max(width, 1e-5) + 0.5);
}

static inline float snowFill(texture2d<float> snowTexture, sampler snowSampler, float2 uv, float clock, float recovery) {
    return smoothstep(0.0, recovery, clock - snowTexture.sample(snowSampler, uv, level(0.0)).r);
}

static inline float4 snowLevels(float4 times, float clock, float recovery) {
    return saturate((clock - times) / recovery);
}

static inline float snowLevelBilinear(texture2d<float> snowTexture, sampler snowSampler, float2 uv, float clock, float recovery) {
    float2 size = float2(snowTexture.get_width(), snowTexture.get_height());
    float2 texel = uv * size - 0.5;
    float2 base = floor(texel);
    float2 t = texel - base;
    float4 levels = snowLevels(snowTexture.gather(snowSampler, (base + 1.0) / size), clock, recovery);
    return mix(mix(levels.w, levels.z, t.x), mix(levels.x, levels.y, t.x), t.y);
}

static inline Cellular cellular(float2 point, float seed) {
    float2 base = floor(point);
    float2 local = point - base;
    float first = 8.0;
    float second = 8.0;
    float2 nearest = base;
    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            float2 offset = float2(float(x), float(y));
            float2 jitter = hash33(float3(base + offset, seed)).xy;
            float distance = length(offset + jitter - local);
            if (distance < first) {
                second = first;
                first = distance;
                nearest = base + offset;
            } else if (distance < second) {
                second = distance;
            }
        }
    }
    return {nearest, second - first};
}

static inline float cellLine(float edge, float footprint) {
    return (1.0 - smoothstep(0.0, footprint * 1.5 + 0.02, edge)) * saturate(1.5 - footprint * 4.0);
}

static inline float3x3 effectShape(constant EffectUniforms &effects) {
    return float3x3(effects.shapeX.xyz, effects.shapeY.xyz, effects.shapeZ.xyz);
}

static inline float3x3 effectUnshape(constant EffectUniforms &effects) {
    return float3x3(effects.unshapeX.xyz, effects.unshapeY.xyz, effects.unshapeZ.xyz);
}

static inline bool effectsActive(constant EffectUniforms &effects) {
    return effects.state.y > 0.5;
}

static inline float effectWeight(float3 direction, float3 center, float radius) {
    return exp(-(1.0 - dot(direction, center)) / (radius * radius));
}

static inline float rippleWave(float3 direction, constant EffectUniforms &effects, thread float3 &slope) {
    float age = effects.ripple.w;
    if (age < 0.0) {
        slope = float3(0.0);
        return 0.0;
    }
    float cosine = clamp(dot(direction, effects.ripple.xyz), -1.0, 1.0);
    float wavelength = effects.wave.z;
    float front = acos(cosine) - effects.wave.w * age;
    float envelope = exp(-effects.state.x * age) * exp(-(front / wavelength) * (front / wavelength));
    float phase = 2.0 * M_PI_F * front / wavelength;
    float profileSlope = envelope * (2.0 * M_PI_F / wavelength * cos(phase) - 2.0 * front / (wavelength * wavelength) * sin(phase));
    float3 away = (direction * cosine - effects.ripple.xyz) / max(sqrt(max(1.0 - cosine * cosine, 0.0)), 1e-4);
    slope = profileSlope * away;
    return envelope * sin(phase);
}

static inline float effectOffset(float3 direction, constant EffectUniforms &effects, thread float3 &slope) {
    float dent = -effects.dent.w * effectWeight(direction, effects.dent.xyz, effects.radii.x);
    float bump = effects.bump.w * effectWeight(direction, effects.bump.xyz, effects.radii.y);
    slope = dent / (effects.radii.x * effects.radii.x) * (effects.dent.xyz - direction * dot(direction, effects.dent.xyz))
          + bump / (effects.radii.y * effects.radii.y) * (effects.bump.xyz - direction * dot(direction, effects.bump.xyz));
    float3 waveSlope;
    float wave = rippleWave(direction, effects, waveSlope);
    slope += effects.wave.y * waveSlope;
    return dent + bump + effects.wave.y * wave;
}

static inline float3 rippleSlope(float3 direction, constant EffectUniforms &effects) {
    float3 slope;
    rippleWave(direction, effects, slope);
    return slope;
}
