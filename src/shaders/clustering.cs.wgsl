// ─────────────────────────────────────────────────────────────
// Clustered Light Assignment Compute Shader
//   • Calculates per-cluster light lists in screen space
//   • Each thread processes one cluster
//   • Outputs list of light indices for that cluster
// ─────────────────────────────────────────────────────────────

@group(0) @binding(0) var<uniform> clusterGrid: vec4<u32>;                   // { x: clustersX, y: clustersY, z: clustersZ, w: maxLightsPerCluster }
@group(0) @binding(1) var<uniform> camera: CameraUniforms;                   // View/projection matrices, near/far planes, etc.
@group(0) @binding(2) var<storage, read> uLightSet: LightSet;                // Input: All scene lights
@group(0) @binding(3) var<storage, read_write> clusterLightIndices: ClusterLightIndexBuffer; // Output: Per-cluster light index lists


// Helper: Convert world-space position → cluster coordinates
fn worldToClusterIndex(worldPos: vec3f) -> vec3i {
    let clipPos = camera.viewProjMat * vec4(worldPos, 1.0f);

    // Perspective divide to get NDC
    var ndcXY = clipPos.xy;
    if (clipPos.w > 0.0f) {
        ndcXY /= clipPos.w;
    }

    // Convert to [0, 1] screen-space
    let screenXY = ndcXY * 0.5 + vec2f(0.5);

    // Logarithmic depth → [0, 1] for Z clustering
    let near = camera.cameraParams.x;
    let far  = camera.cameraParams.y;
    let depth = clamp(log(clipPos.z / near) / log(far / near), 0.0f, 1.0f);

    // Convert screen/depth → cluster indices
    let ix = i32(floor(screenXY.x * f32(clusterGrid.x)));
    let iy = i32(floor(screenXY.y * f32(clusterGrid.y)));
    let iz = i32(floor(depth * f32(clusterGrid.z)));

    return vec3i(ix, iy, iz);
}

// ─────────────────────────────────────────────────────────────
// Compute Shader
//   • Each thread handles one cluster (by index.x)
//   • Populates a list of lights that influence it
// ─────────────────────────────────────────────────────────────
@compute @workgroup_size(${workgroup_size})
fn main(@builtin(global_invocation_id) index: vec3u) {
    let totalClusters = clusterGrid.x * clusterGrid.y * clusterGrid.z;
    if (index.x >= totalClusters) {
        return;
    }

    // Decode 1D index into (x, y, z) cluster position
    let clusterX = i32(index.x % clusterGrid.x);
    let clusterY = i32((index.x / clusterGrid.x) % clusterGrid.y);
    let clusterZ = i32(index.x / (clusterGrid.x * clusterGrid.y));
    let clusterIndex3D = vec3i(clusterX, clusterY, clusterZ);

    // Compute flat buffer offset for this cluster’s light list
    let maxLightsPerCluster = clusterGrid.w;
    let lightListOffset = index.x * maxLightsPerCluster;

    // Counter: how many lights affect this cluster
    var lightsAdded = 0u;

    // Iterate over all lights
    for (var i = 0u; i < uLightSet.numLights; i++) {
        let light = uLightSet.lights[i];

        // Compute light’s AABB in world space using bounding sphere radius
        const r = ${lightRadius};

        let offsets = array<vec3f, 8>(
            vec3f(-r, -r, -r), vec3f( r, -r, -r),
            vec3f(-r,  r, -r), vec3f( r,  r, -r),
            vec3f(-r, -r,  r), vec3f( r, -r,  r),
            vec3f(-r,  r,  r), vec3f( r,  r,  r)
        );

        // Compute light’s AABB in cluster space
        var minIndex = worldToClusterIndex(light.pos + offsets[0]);
        var maxIndex = minIndex;

        for (var j = 1u; j < 8u; j++) {
            let clusterCorner = worldToClusterIndex(light.pos + offsets[j]);
            minIndex = min(minIndex, clusterCorner);
            maxIndex = max(maxIndex, clusterCorner);
        }

        // Early out if light does NOT intersect this cluster
        if (any(clusterIndex3D < minIndex) || any(clusterIndex3D > maxIndex)) {
            continue;
        }

        // Write this light index into the cluster’s light list
        clusterLightIndices.indices[lightListOffset + lightsAdded] = i;
        lightsAdded += 1u;

        // Avoid overflow
        if (lightsAdded >= maxLightsPerCluster) {
            break;
        }
    }


    // Pad remaining slots with sentinel value (0xffffffff)
    if (lightsAdded < maxLightsPerCluster) {
        clusterLightIndices.indices[lightListOffset + lightsAdded] = 2 << 30;
    }
}
