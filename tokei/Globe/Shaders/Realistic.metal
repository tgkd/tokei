#include "GlobeShared.h"

#define KM (2.0 / 6360.0)
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
#define RELIEF_SLOPE 1.0
#define CLOUD_RADIUS (GROUND_RADIUS + 5.0 * KM)
#define CLOUD_RELIEF (6.0 * KM)
#define CLOUD_STEP 0.0025
#define CLOUD_SHADOW 0.65
#define CLOUD_WRAP 0.5
#define GLINT_ROUGHNESS 0.13
#define HALO_NEAR 4.0
#define HALO_FAR 16.0
#define SUN_RADIUS 0.00465
#define SUN_RADIANCE 30.0

vertex FullscreenVertex globeVertex(uint vertexID [[vertex_id]]) {
    float2 corner = float2(float((vertexID << 1) & 2), float(vertexID & 2));
    FullscreenVertex out;
    out.position = float4(corner * 2.0 - 1.0, 0.0, 1.0);
    return out;
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

static float luminance(float3 color) {
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

static float2 sphereUV(float3 direction) {
    float longitude = atan2(direction.x, direction.z);
    float latitude = asin(clamp(direction.y, -1.0, 1.0));
    return float2(longitude / (2.0 * M_PI_F) + 0.5, 0.5 - latitude / M_PI_F);
}

static float valueNoise(float3 p) {
    float3 cell = floor(p);
    float3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float x00 = mix(hash33(cell).x, hash33(cell + float3(1.0, 0.0, 0.0)).x, f.x);
    float x10 = mix(hash33(cell + float3(0.0, 1.0, 0.0)).x, hash33(cell + float3(1.0, 1.0, 0.0)).x, f.x);
    float x01 = mix(hash33(cell + float3(0.0, 0.0, 1.0)).x, hash33(cell + float3(1.0, 0.0, 1.0)).x, f.x);
    float x11 = mix(hash33(cell + float3(0.0, 1.0, 1.0)).x, hash33(cell + float3(1.0, 1.0, 1.0)).x, f.x);
    return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

static float cloudCover(float density) {
    return smoothstep(0.1, 0.8, density);
}

struct Ground {
    float3 albedo;
    float lights;
    float halo;
    float water;
    float2 relief;
};

struct CloudLayer {
    float3 normal;
    float cover;
    float rise;
    float shadow;
};

static float surfaceFootprint(float3 normal, SurfaceCoordinates coordinates) {
    float latitudeScale = length(normal.xz) * 2.0 * M_PI_F;
    float2 spanX = coordinates.dx * float2(latitudeScale, M_PI_F);
    float2 spanY = coordinates.dy * float2(latitudeScale, M_PI_F);
    return max(length(spanX), length(spanY));
}

static CloudLayer cloudLayer(float3 origin, float3 direction, float3 normal, float3 sun, SurfaceCoordinates coordinates,
                             texture2d<float> cloudTexture, sampler surfaceSampler) {
    gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
    float3 hit = sphereHit(origin, direction, CLOUD_RADIUS);
    float3 cloudNormal = hit.z > 0.5 && hit.x > 0.0 ? normalize(origin + direction * hit.x) : normal;

    float muSun = dot(normal, sun);
    float reach = -muSun + safeSqrt(muSun * muSun + CLOUD_RADIUS * CLOUD_RADIUS - GROUND_RADIUS * GROUND_RADIUS);
    float3 shadowNormal = normalize(normal + sun * reach);

    float spacing = max(CLOUD_STEP, surfaceFootprint(normal, coordinates));
    float3 tangent = sun - cloudNormal * dot(cloudNormal, sun);
    float lean = length(tangent);
    float3 toward = lean > 1e-4 ? tangent / lean : float3(0.0);

    float here = cloudTexture.sample(surfaceSampler, sphereUV(cloudNormal), gradient).r;
    float ahead = cloudTexture.sample(surfaceSampler, sphereUV(normalize(cloudNormal + toward * spacing)), gradient).r;
    float shade = cloudTexture.sample(surfaceSampler, sphereUV(shadowNormal), gradient2d(coordinates.dx * 2.0, coordinates.dy * 2.0)).r;

    CloudLayer layer;
    layer.normal = cloudNormal;
    layer.cover = cloudCover(here);
    layer.rise = (cloudCover(ahead) - layer.cover) * CLOUD_RELIEF / spacing * lean;
    layer.shadow = cloudCover(shade) * CLOUD_SHADOW;
    return layer;
}

static float3 cityLightColor(float3 normal, float lights) {
    float region = valueNoise(normal * 40.0);
    float3 sodium = mix(float3(1.0, 0.48, 0.15), float3(1.0, 0.62, 0.30), region);
    float3 white = mix(float3(1.0, 0.80, 0.58), float3(0.92, 0.90, 0.86), region);
    return mix(sodium, white, saturate(lights * 1.5 - 0.2) * smoothstep(0.25, 0.75, region));
}

static float3 terrainNormal(float3 normal, float2 relief) {
    float2 horizontal = float2(normal.z, -normal.x);
    float horizontalLength = length(horizontal);
    float3 east = horizontalLength > 1e-5 ? float3(horizontal.x, 0.0, horizontal.y) / horizontalLength : float3(1.0, 0.0, 0.0);
    float3 north = cross(normal, east);
    return normalize(normal - RELIEF_SLOPE * (relief.x * east + relief.y * north));
}

static float3 shadeGround(Ground ground, float3 normal, float3 glintNormal, float3 direction, float3 sun, float3 lightColor,
                          float night, float cloudShadow, texture2d<float> lut, sampler lutSampler) {
    float muSun = dot(normal, sun);
    float3 transmitted = sunTransmittance(lut, lutSampler, GROUND_RADIUS + 1e-5, muSun);
    float3 sunlight = mix(float3(luminance(transmitted)), transmitted, 0.72) * (1.0 - cloudShadow);
    float3 terrain = terrainNormal(normal, ground.relief);
    float direct = saturate(dot(terrain, sun));
    float3 color = ground.albedo * sunlight * direct / M_PI_F;

    float skyAmount = smoothstep(-0.1, 0.45, muSun);
    color += ground.albedo * float3(0.030, 0.045, 0.080) * skyAmount;

    float3 toward = sun - normal * muSun;
    float towardLength = length(toward);
    float3 skyGlow = towardLength > 1e-4 ? toward / towardLength * 0.985 + normal * 0.1736 : normal;
    float facing = saturate(dot(terrain, skyGlow)) / max(dot(normal, skyGlow), 1e-3);
    float twilight = smoothstep(-0.07, 0.0, muSun) * (1.0 - smoothstep(0.035, 0.17, muSun));
    color += ground.albedo * float3(0.09, 0.045, 0.02) * twilight * facing;
    color += float3(0.0015, 0.0007, 0.0003) * twilight;

    float moonlight = 1.0 - smoothstep(-0.25, 0.02, muSun);
    color += ground.albedo * float3(0.0035, 0.005, 0.010) * moonlight;

    color += lightColor * pow(ground.lights, 1.6) * 0.9 * night;

    float3 toEye = -direction;
    float nv = max(dot(glintNormal, toEye), 1e-3);
    float nl = saturate(dot(glintNormal, sun));
    float3 halfway = normalize(sun + toEye);
    float nh = saturate(dot(glintNormal, halfway));
    float vh = saturate(dot(toEye, halfway));
    float roughness2 = GLINT_ROUGHNESS * GLINT_ROUGHNESS;
    float spread = nh * nh * (roughness2 - 1.0) + 1.0;
    float distribution = roughness2 / (M_PI_F * spread * spread);
    float k = GLINT_ROUGHNESS * 0.5;
    float geometry = nl / (nl * (1.0 - k) + k) * nv / (nv * (1.0 - k) + k);
    float fresnel = 0.02 + 0.98 * pow(1.0 - vh, 5.0);
    float3 glintLight = mix(float3(luminance(transmitted)), transmitted, 0.9) * (1.0 - cloudShadow);
    color += ground.water * glintLight * distribution * fresnel * geometry / (4.0 * nv);

    float skyFresnel = 0.02 + 0.98 * pow(1.0 - saturate(dot(normal, toEye)), 5.0);
    color += ground.water * float3(0.05, 0.08, 0.13) * skyFresnel * skyAmount;

    return color;
}

static float3 shadeClouds(CloudLayer layer, float3 sun, float3 lightColor, float halo, float night,
                          texture2d<float> lut, sampler lutSampler) {
    float mu = dot(layer.normal, sun);
    float3 sunlight = sunTransmittance(lut, lutSampler, CLOUD_RADIUS, mu);
    float lit = saturate((mu - layer.rise + CLOUD_WRAP) / (1.0 + CLOUD_WRAP)) * smoothstep(-0.065, 0.05, mu);
    float albedo = mix(0.7, 0.95, layer.cover);
    float3 color = albedo * sunlight * lit / M_PI_F;
    color += albedo * float3(0.030, 0.045, 0.080) * smoothstep(-0.1, 0.45, mu);
    color += albedo * float3(0.0012, 0.0017, 0.0035) * (1.0 - smoothstep(-0.25, 0.02, mu));
    color += lightColor * halo * 0.3 * night;
    return color;
}

static float3 sunDisk(float3 view, float3 sun, float focal) {
    float angle = safeSqrt(2.0 - 2.0 * dot(view, sun));
    float disk = saturate((SUN_RADIUS - angle) * focal + 0.5);
    return float3(1.0, 0.96, 0.9) * SUN_RADIANCE * disk;
}

static float3 sunGlare(float3 camera, float3 view, float3 sun, texture2d<float> lut, sampler lutSampler) {
    float cameraDistance = length(camera);
    float centerCosine = -dot(sun, camera) / cameraDistance;
    float separation = acos(clamp(centerCosine, -1.0, 1.0));
    float limb = asin(min(GROUND_RADIUS / cameraDistance, 1.0));
    float visible = smoothstep(-SUN_RADIUS, SUN_RADIUS, separation - limb);
    float3 transmittance = float3(1.0);
    float passage = cameraDistance * sin(separation);
    if (centerCosine > 0.0 && passage < TOP_RADIUS) {
        float3 oneWay = lut.sample(lutSampler, transmittanceUV(max(passage, GROUND_RADIUS), 0.0, float2(lut.get_width(), lut.get_height()))).rgb;
        transmittance = oneWay * oneWay;
    }
    float angle = acos(clamp(dot(view, sun), -1.0, 1.0));
    float glow = 0.6 * exp(-angle * angle / (0.012 * 0.012)) + 0.02 / (1.0 + angle * angle / (0.05 * 0.05));
    return float3(1.0, 0.9, 0.78) * transmittance * glow * visible;
}

constant bool realisticEffects [[function_constant(0)]];

fragment half4 globeFragment(FullscreenVertex in [[stage_in]],
                             constant GlobeUniforms &uniforms [[buffer(0)]],
                             constant EffectUniforms &effects [[buffer(2)]],
                             texture2d<float> dayTexture [[texture(0)]],
                             texture2d<float> lightsTexture [[texture(1)]],
                             texture2d<float> waterTexture [[texture(2)]],
                             texture2d<float> lut [[texture(3)]],
                             texture2d<float> cloudTexture [[texture(4)]],
                             texture2d<float> reliefTexture [[texture(5)]],
                             sampler surfaceSampler [[sampler(0)]],
                             sampler lutSampler [[sampler(1)]]) {
    float2 pixel = in.position.xy;
    float focal = uniforms.viewport.z;
    float exposure = uniforms.viewport.w;
    float reveal = uniforms.principal.z;
    float3x3 unshape = effectUnshape(effects);
    float3 origin = realisticEffects ? unshape * uniforms.cameraPosition.xyz : uniforms.cameraPosition.xyz;
    float3 sun = uniforms.sunDirection.xyz;
    float3 ray = globeRay(pixel, focal, uniforms);
    float3 direction = realisticEffects ? normalize(unshape * ray) : normalize(ray);
    float3 view = realisticEffects ? normalize(ray) : direction;

    float along = -dot(origin, direction);
    float coverage = globeCoverage(origin, direction, along, focal);

    float3 ground = sphereHit(origin, direction, GROUND_RADIUS);
    bool groundHit = ground.z > 0.5 && ground.x > 0.0;
    float3 surfacePoint = groundHit ? origin + direction * ground.x : normalize(origin + direction * max(along, 0.0));
    float groundDistance = groundHit ? ground.x : length(surfacePoint - origin);
    float3 normal = normalize(surfacePoint);

    SurfaceCoordinates coordinates = surfaceCoordinates(normal);
    float2 uv = coordinates.uv;

    float3 background = stars(view, focal);
    float3 shell = sphereHit(origin, direction, TOP_RADIUS);
    bool inAtmosphere = shell.z > 0.5 && shell.y > 0.0;
    float entry = max(shell.x, 0.0);

    float3 missColor = background;
    if (coverage < 1.0) {
        float3 sky = background + sunDisk(view, sun, focal);
        missColor = sky;
        if (inAtmosphere) {
            Scattering air = atmosphere(origin, direction, sun, entry, shell.y, false, lut, lutSampler);
            missColor = sky * air.transmittance + air.light * exposure;
        }
    }

    float3 hitColor = float3(0.0);
    if (coverage > 0.0) {
        gradient2d gradient = gradient2d(coordinates.dx, coordinates.dy);
        float night = 1.0 - smoothstep(-0.1736, 0.0175, dot(normal, sun));
        Ground surface;
        surface.albedo = dayTexture.sample(surfaceSampler, uv, gradient).rgb;
        surface.lights = 0.0;
        surface.halo = 0.0;
        surface.water = waterTexture.sample(surfaceSampler, uv, gradient).r;
        surface.relief = reliefTexture.sample(surfaceSampler, uv, gradient).xy;
        float3 lightColor = float3(0.0);
        if (night > 0.0) {
            surface.lights = lightsTexture.sample(surfaceSampler, uv, gradient).r;
            float haloNear = lightsTexture.sample(surfaceSampler, uv, gradient2d(coordinates.dx * HALO_NEAR, coordinates.dy * HALO_NEAR)).r;
            float haloFar = lightsTexture.sample(surfaceSampler, uv, gradient2d(coordinates.dx * HALO_FAR, coordinates.dy * HALO_FAR)).r;
            surface.halo = 0.5 * (haloNear + haloFar);
            lightColor = cityLightColor(normal, surface.lights);
        }
        CloudLayer clouds = cloudLayer(origin, direction, normal, sun, coordinates, cloudTexture, surfaceSampler);

        float3 glintNormal = normal;
        if (realisticEffects && effectsActive(effects)) {
            float3 slope;
            effectOffset(normal, effects, slope);
            glintNormal = normalize(normal - slope - effects.wave.x * rippleSlope(normal, effects));
        }
        float3 color = shadeGround(surface, normal, glintNormal, direction, sun, lightColor, night, clouds.shadow, lut, lutSampler);
        float3 cloudColor = shadeClouds(clouds, sun, lightColor, surface.halo, night, lut, lutSampler);
        color = mix(color, cloudColor, clouds.cover);
        color += lightColor * pow(surface.halo, 1.5) * 0.12 * night * (1.0 - clouds.cover);

        Scattering air = atmosphere(origin, direction, sun, entry, max(groundDistance, entry), true, lut, lutSampler);
        float haze = mix(0.2, 0.85, smoothstep(-0.12, 0.10, dot(normal, sun)));
        hitColor = (color * air.transmittance + air.light * haze) * exposure;
        if (realisticEffects && effectsActive(effects)) {
            hitColor += float3(1.0, 0.55, 0.22) * effects.radii.z * effectWeight(normal, effects.bump.xyz, effects.radii.y);
        }
    }

    float3 color = mix(missColor, hitColor, coverage);
    color += sunGlare(uniforms.cameraPosition.xyz, view, sun, lut, lutSampler);
    color = mix(background, color, reveal);
    return finishColor(color, pixel);
}
