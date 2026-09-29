#include "GlobeShared.h"

struct TerrainUniforms {
    float4 coast;
    float4 lift;
    float4 relief;
    float4 profile;
    float4 grid;
};

struct TerrainSample {
    float coastDistance;
    float height;
    float relief;
    float3 normal;
};

struct GridTap {
    float value;
    float2 slope;
};

constant float3 faceNormals[6] = {float3(1, 0, 0), float3(-1, 0, 0), float3(0, 1, 0), float3(0, -1, 0), float3(0, 0, 1), float3(0, 0, -1)};
constant float3 faceUs[6] = {float3(0, 1, 0), float3(0, 0, 1), float3(0, 0, 1), float3(1, 0, 0), float3(1, 0, 0), float3(0, 1, 0)};
constant float3 faceVs[6] = {float3(0, 0, 1), float3(0, 1, 0), float3(1, 0, 0), float3(0, 0, 1), float3(0, 1, 0), float3(1, 0, 0)};

static float4 projectToClip(float3 worldPosition, constant GlobeUniforms &uniforms) {
    float3 offset = worldPosition - uniforms.cameraPosition.xyz;
    float depth = dot(offset, uniforms.cameraForward.xyz);
    float focal = uniforms.viewport.z;
    float2 pixel = float2(uniforms.principal.x + focal * dot(offset, uniforms.cameraRight.xyz) / depth,
                          uniforms.principal.y - focal * dot(offset, uniforms.cameraUp.xyz) / depth);
    float2 ndc = float2(pixel.x / uniforms.viewport.x * 2.0 - 1.0,
                       1.0 - pixel.y / uniforms.viewport.y * 2.0);
    float distance = length(uniforms.cameraPosition.xyz);
    float near = max(distance - 1.1, 0.05);
    float far = distance + 1.1;
    return float4(ndc * depth, far * (depth - near) / (far - near), depth);
}

static float placedRadius(float3 direction, float lift, constant EffectUniforms &effects) {
    if (effectsActive(effects)) {
        float3 slope;
        return 1.0 + lift + effectOffset(direction, effects, slope);
    }
    return 1.0 + lift;
}

static MeshFragmentIn placedVertex(float3 spherePosition, constant GlobeUniforms &uniforms, constant EffectUniforms &effects) {
    float3 worldPosition = effectsActive(effects) ? effectShape(effects) * spherePosition : spherePosition;
    MeshFragmentIn out;
    out.position = projectToClip(worldPosition, uniforms);
    out.spherePosition = spherePosition;
    return out;
}

static float cubeTangent(float parameter) {
    return abs(parameter) == 1.0 ? parameter : tan(parameter * M_PI_F / 4.0);
}

static float gridValue(const device half *grid, int2 size, int x, int y) {
    int column = ((x % size.x) + size.x) % size.x;
    int row = clamp(y, 0, size.y - 1);
    return float(grid[row * size.x + column]);
}

static float2 gridPosition(float3 direction, float2 size) {
    float longitude = atan2(direction.x, direction.z);
    float latitude = asin(clamp(direction.y, -1.0, 1.0));
    return float2((longitude / (2.0 * M_PI_F) + 0.5) * size.x - 0.5, (0.5 - latitude / M_PI_F) * size.y - 0.5);
}

static float gridSample(const device half *grid, float2 size, float2 position) {
    int2 extent = int2(size);
    float2 base = floor(position);
    float2 fraction = position - base;
    int x = int(base.x);
    int y = int(base.y);
    int left = x < 0 ? x + extent.x : (x >= extent.x ? x - extent.x : x);
    int right = left + 1 >= extent.x ? 0 : left + 1;
    int top = clamp(y, 0, extent.y - 1) * extent.x;
    int bottom = clamp(y + 1, 0, extent.y - 1) * extent.x;
    float upper = float(grid[top + left]) * (1.0 - fraction.x) + float(grid[top + right]) * fraction.x;
    float lower = float(grid[bottom + left]) * (1.0 - fraction.x) + float(grid[bottom + right]) * fraction.x;
    return upper * (1.0 - fraction.y) + lower * fraction.y;
}

static GridTap gridTap(const device half *grid, float2 size, float2 position) {
    int2 extent = int2(size);
    float2 base = floor(position);
    float2 fraction = position - base;
    int x = int(base.x);
    int y = int(base.y);
    float v00 = gridValue(grid, extent, x, y);
    float v10 = gridValue(grid, extent, x + 1, y);
    float v01 = gridValue(grid, extent, x, y + 1);
    float v11 = gridValue(grid, extent, x + 1, y + 1);
    float east00 = v10 - gridValue(grid, extent, x - 1, y);
    float east10 = gridValue(grid, extent, x + 2, y) - v00;
    float east01 = v11 - gridValue(grid, extent, x - 1, y + 1);
    float east11 = gridValue(grid, extent, x + 2, y + 1) - v01;
    float south00 = v01 - gridValue(grid, extent, x, y - 1);
    float south10 = v11 - gridValue(grid, extent, x + 1, y - 1);
    float south01 = gridValue(grid, extent, x, y + 2) - v00;
    float south11 = gridValue(grid, extent, x + 1, y + 2) - v10;
    float2 upper = float2(mix(v00, v10, fraction.x), mix(east00, east10, fraction.x));
    float2 lower = float2(mix(v01, v11, fraction.x), mix(east01, east11, fraction.x));
    float value = mix(upper.x, lower.x, fraction.y);
    float east = mix(upper.y, lower.y, fraction.y) * 0.5;
    float south = mix(mix(south00, south10, fraction.x), mix(south01, south11, fraction.x), fraction.y) * 0.5;
    return {value, float2(east * size.x / (2.0 * M_PI_F), -south * size.y / M_PI_F)};
}

static float3 surfaceGradient(float3 direction, float2 slope) {
    float cosine = max(length(direction.xz), 1e-3);
    float3 east = float3(direction.z, 0.0, -direction.x) / cosine;
    float3 north = float3(-direction.y * direction.x / cosine, cosine, -direction.y * direction.z / cosine);
    return east * (slope.x / cosine) + north * slope.y;
}

static float4 profileAt(const device float4 *profile, constant TerrainUniforms &terrain, float distance) {
    float last = terrain.profile.z - 1.0;
    float position = clamp((distance - terrain.profile.x) / terrain.profile.y, 0.0, last);
    float base = floor(position);
    uint index = uint(base);
    uint next = uint(min(base + 1.0, last));
    return mix(profile[index], profile[next], position - base);
}

static float terrainHeight(float3 direction,
                           constant TerrainUniforms &terrain,
                           const device half *coast,
                           const device half *lift,
                           const device float4 *profile) {
    float2 unit = float2(atan2(direction.x, direction.z) / (2.0 * M_PI_F) + 0.5, 0.5 - asin(clamp(direction.y, -1.0, 1.0)) / M_PI_F);
    float distance = gridSample(coast, terrain.coast.xy, unit * terrain.coast.xy - 0.5);
    return profileAt(profile, terrain, distance).x + gridSample(lift, terrain.lift.xy, unit * terrain.lift.xy - 0.5);
}

static TerrainSample terrainSample(float3 direction,
                                   constant TerrainUniforms &terrain,
                                   const device half *coast,
                                   const device half *lift,
                                   const device half *relief,
                                   const device float4 *profile) {
    GridTap distance = gridTap(coast, terrain.coast.xy, gridPosition(direction, terrain.coast.xy));
    float2 liftPosition = gridPosition(direction, terrain.lift.xy);
    GridTap height = gridTap(lift, terrain.lift.xy, liftPosition);
    float4 shape = profileAt(profile, terrain, distance.value);
    float total = shape.x + height.value;
    float3 gradient = surfaceGradient(direction, shape.y * distance.slope + height.slope);
    TerrainSample sample;
    sample.coastDistance = distance.value;
    sample.height = total;
    sample.relief = shape.z + gridSample(relief, terrain.relief.xy, gridPosition(direction, terrain.relief.xy));
    sample.normal = normalize(direction * (1.0 + total) - gradient);
    return sample;
}

vertex MeshFragmentIn meshVertex(uint vertexID [[vertex_id]],
                                 uint instanceID [[instance_id]],
                                 constant GlobeUniforms &uniforms [[buffer(0)]],
                                 const device uint *nodes [[buffer(1)]],
                                 constant EffectUniforms &effects [[buffer(2)]],
                                 constant TerrainUniforms &terrain [[buffer(3)]],
                                 const device half *coast [[buffer(4)]],
                                 const device half *lift [[buffer(5)]],
                                 const device float4 *profile [[buffer(6)]]) {
    uint node = nodes[instanceID];
    uint face = node >> 28;
    uint level = (node >> 24) & 15u;
    float2 origin = float2((node >> 12) & 4095u, node & 4095u);
    uint cells = uint(terrain.grid.x);
    uint side = cells + 1u;
    uint2 corner;
    bool skirt = vertexID >= side * side;
    if (skirt) {
        uint ring = vertexID - side * side;
        uint edge = ring / cells;
        uint step = ring % cells;
        if (edge == 0u) {
            corner = uint2(step, 0u);
        } else if (edge == 1u) {
            corner = uint2(cells, step);
        } else if (edge == 2u) {
            corner = uint2(cells - step, cells);
        } else {
            corner = uint2(0u, cells - step);
        }
    } else {
        corner = uint2(vertexID % side, vertexID / side);
    }
    float size = 2.0 / float(1u << level);
    float2 parameter = -1.0 + size * (origin + float2(corner) / float(cells));
    float3 direction = normalize(faceNormals[face] + faceUs[face] * cubeTangent(parameter.x) + faceVs[face] * cubeTangent(parameter.y));
    float height = terrainHeight(direction, terrain, coast, lift, profile);
    float radius = placedRadius(direction, effectsActive(effects) ? height * effects.radii.w : height, effects);
    if (skirt) {
        radius -= 0.5 * size * M_PI_F / 4.0 / float(cells) + 1e-4;
    }
    return placedVertex(direction * radius, uniforms, effects);
}

vertex MeshFragmentIn cloudVertex(uint vertexID [[vertex_id]],
                                  constant GlobeUniforms &uniforms [[buffer(0)]],
                                  const device packed_float3 *directions [[buffer(1)]],
                                  constant EffectUniforms &effects [[buffer(2)]],
                                  constant float4 &shell [[buffer(3)]]) {
    float3 direction = float3(directions[vertexID]);
    float lift = effectsActive(effects) ? max(shell.x * effects.radii.w, shell.y) : shell.x;
    return placedVertex(direction * placedRadius(direction, lift, effects), uniforms, effects);
}

kernel void reliefKernel(texture2d<float, access::write> target [[texture(0)]],
                         constant TerrainUniforms &terrain [[buffer(0)]],
                         const device half *coast [[buffer(1)]],
                         const device half *lift [[buffer(2)]],
                         const device half *relief [[buffer(3)]],
                         const device float4 *profile [[buffer(4)]],
                         uint2 texel [[thread_position_in_grid]]) {
    uint width = target.get_width();
    uint height = target.get_height();
    if (texel.x >= width || texel.y >= height) {
        return;
    }
    float latitude = (0.5 - (float(texel.y) + 0.5) / float(height)) * M_PI_F;
    float longitude = ((float(texel.x) + 0.5) / float(width) - 0.5) * 2.0 * M_PI_F;
    float3 direction = float3(cos(latitude) * sin(longitude), sin(latitude), cos(latitude) * cos(longitude));
    TerrainSample sample = terrainSample(direction, terrain, coast, lift, relief, profile);
    const float seaWeight = 6.0;
    float weight = sample.coastDistance < 0.0 ? seaWeight : 1.0;
    target.write(float4(sample.normal * weight, sample.relief), texel);
}
