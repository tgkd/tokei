#include <metal_stdlib>
using namespace metal;

#define KM (2.0 / 6360.0)
#define GROUND_RADIUS 1.0
#define TOP_RADIUS (1.0 + 80.0 * KM)
#define RAYLEIGH_HEIGHT (8.0 * KM)
#define MIE_HEIGHT (1.2 * KM)
#define OZONE_CENTER (25.0 * KM)
#define OZONE_HALF_WIDTH (15.0 * KM)
#define PER_KM (1.0 / KM)
#define RAYLEIGH_SCATTERING (float3(5.802e-3, 13.558e-3, 33.1e-3) * PER_KM)
#define MIE_SCATTERING (3.996e-3 * PER_KM)
#define MIE_EXTINCTION (4.40e-3 * PER_KM)
#define OZONE_ABSORPTION (float3(0.650e-3, 1.881e-3, 0.085e-3) * 0.6 * PER_KM)
#define MIE_G 0.8

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

vertex FullscreenVertex globeVertex(uint vertexID [[vertex_id]]) {
    float2 corner = float2(float((vertexID << 1) & 2), float(vertexID & 2));
    FullscreenVertex out;
    out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
    return out;
}

static float safeSqrt(float value) {
    return sqrt(max(value, 0.0));
}

static float3 densities(float altitude) {
    float rayleigh = exp(-max(altitude, 0.0) / RAYLEIGH_HEIGHT);
    float mie = exp(-max(altitude, 0.0) / MIE_HEIGHT);
    float ozone = max(0.0, 1.0 - abs(altitude - OZONE_CENTER) / OZONE_HALF_WIDTH);
    return float3(rayleigh, mie, ozone);
}

static float3 extinction(float3 density) {
    return RAYLEIGH_SCATTERING * density.x + MIE_EXTINCTION * density.y + OZONE_ABSORPTION * density.z;
}

static float distanceToTop(float r, float mu) {
    float discriminant = r * r * (mu * mu - 1.0) + TOP_RADIUS * TOP_RADIUS;
    return max(-r * mu + safeSqrt(discriminant), 0.0);
}

static float2 transmittanceUV(float r, float mu, float2 size) {
    float horizon = sqrt(TOP_RADIUS * TOP_RADIUS - GROUND_RADIUS * GROUND_RADIUS);
    float rho = safeSqrt(r * r - GROUND_RADIUS * GROUND_RADIUS);
    float d = distanceToTop(r, mu);
    float dMin = TOP_RADIUS - r;
    float dMax = rho + horizon;
    float xMu = clamp((d - dMin) / max(dMax - dMin, 1e-6), 0.0, 1.0);
    float xR = clamp(rho / horizon, 0.0, 1.0);
    return float2(0.5 / size.x + xMu * (1.0 - 1.0 / size.x), 0.5 / size.y + xR * (1.0 - 1.0 / size.y));
}

kernel void transmittanceKernel(texture2d<float, access::write> lut [[texture(0)]],
                                uint2 gid [[thread_position_in_grid]]) {
    float2 size = float2(lut.get_width(), lut.get_height());
    if (gid.x >= uint(size.x) || gid.y >= uint(size.y)) {
        return;
    }
    float2 uv = (float2(gid) + 0.5) / size;
    float xMu = (uv.x - 0.5 / size.x) / (1.0 - 1.0 / size.x);
    float xR = (uv.y - 0.5 / size.y) / (1.0 - 1.0 / size.y);
    float horizon = sqrt(TOP_RADIUS * TOP_RADIUS - GROUND_RADIUS * GROUND_RADIUS);
    float rho = horizon * xR;
    float r = sqrt(rho * rho + GROUND_RADIUS * GROUND_RADIUS);
    float dMin = TOP_RADIUS - r;
    float dMax = rho + horizon;
    float d = dMin + xMu * (dMax - dMin);
    float mu = d <= 0.0 ? 1.0 : (horizon * horizon - rho * rho - d * d) / (2.0 * r * d);
    mu = clamp(mu, -1.0, 1.0);

    float pathLength = distanceToTop(r, mu);
    const int steps = 128;
    float dt = pathLength / float(steps);
    float3 depth = float3(0.0);
    for (int i = 0; i < steps; i++) {
        float t = (float(i) + 0.5) * dt;
        float altitude = sqrt(r * r + t * t + 2.0 * r * mu * t) - GROUND_RADIUS;
        depth += extinction(densities(altitude)) * dt;
    }
    lut.write(float4(exp(-depth), 1.0), gid);
}

static float3 sunTransmittance(texture2d<float> lut, sampler lutSampler, float r, float muSun) {
    float sinHorizon = min(GROUND_RADIUS / r, 1.0);
    float cosHorizon = -safeSqrt(1.0 - sinHorizon * sinHorizon);
    float visible = smoothstep(-0.0045, 0.0045, muSun - cosHorizon);
    float2 uv = transmittanceUV(r, max(muSun, cosHorizon + 1e-4), float2(lut.get_width(), lut.get_height()));
    return lut.sample(lutSampler, uv).rgb * visible;
}

static float rayleighPhase(float mu) {
    return 3.0 / (16.0 * M_PI_F) * (1.0 + mu * mu);
}

static float miePhase(float mu) {
    float g2 = MIE_G * MIE_G;
    float denominator = (2.0 + g2) * pow(max(1.0 + g2 - 2.0 * MIE_G * mu, 1e-4), 1.5);
    return 3.0 / (8.0 * M_PI_F) * (1.0 - g2) * (1.0 + mu * mu) / denominator;
}

static float3 sphereHit(float3 origin, float3 direction, float radius) {
    float b = dot(origin, direction);
    float c = dot(origin, origin) - radius * radius;
    float discriminant = b * b - c;
    if (discriminant < 0.0) {
        return float3(0.0, 0.0, 0.0);
    }
    float root = sqrt(discriminant);
    return float3(-b - root, -b + root, 1.0);
}

struct Scattering {
    float3 light;
    float3 transmittance;
};

static void march(float3 origin, float3 direction, float3 sun, float start, float end, int steps, bool denseAtEnd,
                  float phaseR, float phaseM, texture2d<float> lut, sampler lutSampler, thread Scattering &result) {
    float span = end - start;
    if (span <= 0.0) {
        return;
    }
    for (int i = 0; i < steps; i++) {
        float a = float(i) / float(steps);
        float b = float(i + 1) / float(steps);
        float ta = denseAtEnd ? end - span * (1.0 - a) * (1.0 - a) : start + span * a * a;
        float tb = denseAtEnd ? end - span * (1.0 - b) * (1.0 - b) : start + span * b * b;
        float dt = tb - ta;
        float3 position = origin + direction * (0.5 * (ta + tb));
        float r = length(position);
        float3 density = densities(r - GROUND_RADIUS);
        float3 sigma = extinction(density);
        float3 sunlight = sunTransmittance(lut, lutSampler, r, dot(position, sun) / r);
        float3 scattering = (RAYLEIGH_SCATTERING * density.x * phaseR + MIE_SCATTERING * density.y * phaseM) * sunlight;
        float3 stepTransmittance = exp(-sigma * dt);
        result.light += result.transmittance * (scattering - scattering * stepTransmittance) / max(sigma, float3(1e-6));
        result.transmittance *= stepTransmittance;
    }
}

static Scattering atmosphere(float3 origin, float3 direction, float3 sun, float start, float end, bool hitsGround,
                             texture2d<float> lut, sampler lutSampler) {
    Scattering result;
    result.light = float3(0.0);
    result.transmittance = float3(1.0);
    float mu = dot(direction, sun);
    float phaseR = rayleighPhase(mu);
    float phaseM = miePhase(mu);
    if (hitsGround) {
        march(origin, direction, sun, start, end, 20, true, phaseR, phaseM, lut, lutSampler, result);
    } else {
        float middle = clamp(-dot(origin, direction), start, end);
        march(origin, direction, sun, start, middle, 12, true, phaseR, phaseM, lut, lutSampler, result);
        march(origin, direction, sun, middle, end, 12, false, phaseR, phaseM, lut, lutSampler, result);
    }
    return result;
}

static float hash12(float2 p) {
    float3 q = fract(float3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

static float3 hash33(float3 p) {
    p = fract(p * float3(0.1031, 0.1030, 0.0973));
    p += dot(p, p.yxz + 33.33);
    return fract((p.xxy + p.yxx) * p.zyx);
}

static float3 faceDirection(float face, float2 coordinate) {
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

static float3 stars(float3 direction, float focal) {
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

static float3 shadeSurface(float3 normal, float3 direction, float3 sun, float3 albedo, float lights, float water,
                           texture2d<float> lut, sampler lutSampler) {
    float muSun = dot(normal, sun);
    float3 transmitted = sunTransmittance(lut, lutSampler, GROUND_RADIUS + 1e-5, muSun);
    float3 sunlight = mix(float3(dot(transmitted, float3(0.2126, 0.7152, 0.0722))), transmitted, 0.72);
    float direct = max(muSun, 0.0);
    float3 color = albedo * sunlight * direct / M_PI_F;

    float skyAmount = smoothstep(-0.1, 0.45, muSun);
    color += albedo * float3(0.030, 0.045, 0.080) * skyAmount;

    float twilight = smoothstep(-0.07, 0.0, muSun) * (1.0 - smoothstep(0.035, 0.17, muSun));
    color += albedo * float3(0.09, 0.045, 0.02) * twilight;
    color += float3(0.0015, 0.0007, 0.0003) * twilight;

    float moonlight = 1.0 - smoothstep(-0.25, 0.02, muSun);
    color += albedo * float3(0.0035, 0.005, 0.010) * moonlight;

    float night = 1.0 - smoothstep(-0.1736, 0.0175, muSun);
    float glow = pow(lights, 1.6);
    float3 lightColor = mix(float3(1.0, 0.56, 0.24), float3(1.0, 0.86, 0.66), saturate(lights * 1.4));
    color += lightColor * glow * 0.9 * night;

    float3 halfway = normalize(sun - direction);
    float nh = saturate(dot(normal, halfway));
    float fresnel = 0.02 + 0.98 * pow(1.0 - saturate(dot(normal, -direction)), 5.0);
    float lobe = pow(nh, 300.0) * 0.32 + pow(nh, 48.0) * 0.035;
    color += water * sunlight * direct * lobe * (0.3 + 0.7 * fresnel);

    return color;
}

static float3 tonemap(float3 color) {
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

static float3 encodeSRGB(float3 color) {
    float3 c = saturate(color);
    return select(1.055 * pow(c, float3(1.0 / 2.4)) - 0.055, c * 12.92, c <= 0.0031308);
}

fragment half4 globeFragment(FullscreenVertex in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             texture2d<float> dayTexture [[texture(0)]],
                             texture2d<float> lightsTexture [[texture(1)]],
                             texture2d<float> waterTexture [[texture(2)]],
                             texture2d<float> lut [[texture(3)]],
                             sampler surfaceSampler [[sampler(0)]],
                             sampler lutSampler [[sampler(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float exposure = uniforms.viewport.w;
    float reveal = uniforms.principal.z;
    float3 origin = uniforms.cameraPosition.xyz;
    float3 sun = uniforms.sunDirection.xyz;
    float3 direction = normalize(uniforms.cameraForward.xyz * focal
                                 + uniforms.cameraRight.xyz * (pixel.x - uniforms.principal.x)
                                 - uniforms.cameraUp.xyz * (pixel.y - uniforms.principal.y));

    float along = -dot(origin, direction);
    float closestDistance = length(origin + direction * along);
    float edgePixels = (closestDistance - GROUND_RADIUS) * focal / max(along, 1e-3);
    float coverage = saturate(0.5 - edgePixels);

    float3 ground = sphereHit(origin, direction, GROUND_RADIUS);
    bool groundHit = ground.z > 0.5 && ground.x > 0.0;
    float3 surfacePoint = groundHit ? origin + direction * ground.x : normalize(origin + direction * max(along, 0.0));
    float groundDistance = groundHit ? ground.x : length(surfacePoint - origin);
    float3 normal = normalize(surfacePoint);

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

    float3 background = stars(direction, focal);
    float3 shell = sphereHit(origin, direction, TOP_RADIUS);
    bool inAtmosphere = shell.z > 0.5 && shell.y > 0.0;
    float entry = max(shell.x, 0.0);

    float3 missColor = background;
    if (coverage < 1.0 && inAtmosphere) {
        Scattering air = atmosphere(origin, direction, sun, entry, shell.y, false, lut, lutSampler);
        missColor = background * air.transmittance + air.light * exposure;
    }

    float3 hitColor = float3(0.0);
    if (coverage > 0.0) {
        gradient2d gradient = gradient2d(dx, dy);
        float3 albedo = dayTexture.sample(surfaceSampler, uv, gradient).rgb;
        float lights = lightsTexture.sample(surfaceSampler, uv, gradient).r;
        float water = waterTexture.sample(surfaceSampler, uv, gradient).r;
        float3 surface = shadeSurface(normal, direction, sun, albedo, lights, water, lut, lutSampler);
        Scattering air = atmosphere(origin, direction, sun, entry, max(groundDistance, entry), true, lut, lutSampler);
        float haze = mix(0.2, 0.85, smoothstep(-0.12, 0.10, dot(normal, sun)));
        hitColor = (surface * air.transmittance + air.light * haze) * exposure;
    }

    float3 color = mix(missColor, hitColor, coverage);
    color = mix(background, color, reveal);
    color = encodeSRGB(tonemap(color));
    float noise = (hash12(pixel) + hash12(pixel + 71.3) - 1.0) / 255.0;
    return half4(half3(color + noise), 1.0h);
}
