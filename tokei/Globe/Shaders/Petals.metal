#include "GlobeShared.h"

struct PetalBurst {
    float4 origin;
    float4 down;
    float4 wind;
    float4 motion;
    float4 shape;
    float4 timing;
};

static float3 petalPerpendicular(float3 axis) {
    return normalize(cross(abs(axis.y) < 0.9 ? float3(0.0, 1.0, 0.0) : float3(1.0, 0.0, 0.0), axis));
}

vertex PetalFragmentIn petalVertex(uint vertexID [[vertex_id]],
                                   uint instanceID [[instance_id]],
                                   constant GlobeUniforms &uniforms [[buffer(0)]],
                                   constant PetalBurst &burst [[buffer(1)]]) {
    float index = float(instanceID);
    float seed = burst.wind.w;
    float3 a = hash33(float3(index * 1.37 + 0.5, seed, 3.1));
    float3 b = hash33(float3(seed + 2.3, index * 0.71 + 2.3, 7.7));
    float3 c = hash33(float3(index * 2.11 + 1.9, 11.3, seed + 0.7));
    float life = burst.motion.w * mix(0.72, 1.0, a.y);
    float age = burst.down.w - a.x * burst.timing.x;

    PetalFragmentIn out;
    out.worldPosition = float3(0.0);
    out.normal = float3(0.0, 0.0, 1.0);
    out.local = float2(0.0);
    out.fade = 0.0;
    out.random = c.z;
    if (age <= 0.0 || age >= life) {
        out.position = float4(2.0, 2.0, 2.0, 1.0);
        return out;
    }

    float3 axis = burst.origin.xyz;
    float3 tangent = petalPerpendicular(axis);
    float3 bitangent = cross(axis, tangent);
    float cosTheta = 1.0 - a.z * (1.0 - cos(burst.origin.w));
    float sinTheta = sqrt(max(1.0 - cosTheta * cosTheta, 0.0));
    float phi = 2.0 * M_PI_F * b.x;
    float3 direction = axis * cosTheta + (tangent * cos(phi) + bitangent * sin(phi)) * sinTheta;
    float3 start = direction * (1.0 + burst.shape.w * mix(0.55, 1.0, b.y));

    float3 down = burst.down.xyz;
    float3 launch = (direction * mix(0.35, 1.0, b.z) + (tangent * (c.x - 0.5) + bitangent * (c.y - 0.5)) * 0.9) * burst.motion.z;
    float3 terminal = down * burst.motion.x * mix(0.7, 1.25, c.y) + burst.wind.xyz * mix(0.6, 1.2, a.z);
    float tau = max(burst.motion.y, 1e-3);
    float settle = 1.0 - exp(-age / tau);
    float3 position = start + terminal * age + (launch - terminal) * tau * settle;

    float3 across = petalPerpendicular(down);
    float psi = 2.0 * M_PI_F * c.z;
    float3 swayA = across * cos(psi) + cross(down, across) * sin(psi);
    float3 swayB = cross(down, swayA);
    float omega = mix(2.2, 4.2, a.z);
    float phase = 2.0 * M_PI_F * b.x;
    float wobble = sin(omega * age + phase);
    position += (swayA * wobble + swayB * 0.45 * sin(1.7 * omega * age + phase * 1.3)) * burst.shape.y * settle;

    float3 spinAxis = normalize(hash33(float3(index + 0.3, seed + 5.0, 17.0)) - 0.5 + 1e-3);
    float3 u0 = petalPerpendicular(spinAxis);
    float3 v0 = cross(spinAxis, u0);
    float spin = burst.shape.z * mix(0.5, 1.4, b.y) * (c.x < 0.5 ? -1.0 : 1.0);
    float angle = spin * age + phase + 0.7 * wobble;
    float3 u = u0 * cos(angle) + spinAxis * sin(angle);
    float3 normal = spinAxis * cos(angle) - u0 * sin(angle);
    float roll = phase + 0.9 * (b.z - 0.5) * age;
    float3 across0 = u * cos(roll) + v0 * sin(roll);
    float3 across1 = v0 * cos(roll) - u * sin(roll);

    float size = burst.shape.x * mix(0.7, 1.3, c.y);
    float grow = smoothstep(0.0, 0.3, age) * (1.0 - smoothstep(life - 0.7, life, age));
    float2 corner = float2(float(vertexID & 1u) * 2.0 - 1.0, float((vertexID >> 1) & 1u) * 2.0 - 1.0);
    float3 world = position + (across0 * corner.x + across1 * corner.y * 0.8) * size * max(grow, 1e-3);

    out.position = projectToClip(world, uniforms);
    out.worldPosition = world;
    out.normal = normal;
    out.local = corner;
    out.fade = grow;
    return out;
}
