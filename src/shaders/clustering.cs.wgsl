@group(${bindGroup_scene}) @binding(0) var<storage, read_write> clusterSet: ClusterSet;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<uniform> camera: CameraUniforms;

fn doesLightIntersectCluster(lightPos: vec3f, clusterMinBounds: vec3f, clusterMaxbounds: vec3f) -> bool {
    let closestPoint = max(clusterMinBounds, min(lightPos, clusterMaxbounds));
    let distance = closestPoint - lightPos;
    let distanceSquared = dot(distance, distance);

    return distanceSquared < (${lightRadius} * ${lightRadius});
}

@compute
@workgroup_size(${computeClustersWorkgroupSize})
fn main(@builtin(global_invocation_id) global_idx: vec3u) {
    if (global_idx.x >= clusterSet.clusterDims.x ||
        global_idx.y >= clusterSet.clusterDims.y ||
        global_idx.z >= clusterSet.clusterDims.z ) {
            return;
    }

    let clusterIndex = global_idx.x
                     + (global_idx.y * clusterSet.clusterDims.x)
                     + (global_idx.z * clusterSet.clusterDims.x * clusterSet.clusterDims.y);


    /* Calculating cluster bounds */
    var minBounds: vec3u;
    var maxBounds: vec3u;

    minBounds.x = (global_idx.x * camera.screenDims.x) / clusterSet.clusterDims.x;
    maxBounds.x = minBounds.x + (camera.screenDims.x / clusterSet.clusterDims.x);

    minBounds.y = (global_idx.y * camera.screenDims.y) / clusterSet.clusterDims.y;
    maxBounds.y = minBounds.y + (camera.screenDims.y / clusterSet.clusterDims.y);

    // For the min and max z-bounds, we operate in NDC space where the near plane is at -1 and the far plane is at 1
    // Thus, the float 2.0 represents the distance between the near and far planes.
    minBounds.z = (global_idx.z * 2 / clusterSet.clusterDims.z) - 1;        // subtract 1, the near plane in NDC
    maxBounds.z = minBounds.z + (2 / clusterSet.clusterDims.z);

    // Convert the screen-space bounds to view space
    // First, convert XY screen space bounds to NDC space
    minBounds.x = 2 * (minBounds.x / camera.screenDims.x) - 1;
    minBounds.y = 2 * (minBounds.y / camera.screenDims.y) - 1;
    maxBounds.x = 2 * (maxBounds.x / camera.screenDims.x) - 1;
    maxBounds.y = 2 * (maxBounds.y / camera.screenDims.y) - 1;

    // Next, convert the NDC space bounds to view space

    let minBounds32f = (camera.invProjMat * vec4f(f32(minBounds.x), f32(minBounds.y), f32(minBounds.z), 1.0)).xyz;
    let maxBounds32f = (camera.invProjMat * vec4f(f32(maxBounds.x), f32(maxBounds.y), f32(maxBounds.z), 1.0)).xyz;

    clusterSet.clusters[clusterIndex].minBounds = minBounds32f;
    clusterSet.clusters[clusterIndex].maxBounds = maxBounds32f;

    /* Assigning lights to clusters */
    var lightCount = 0u;
    for (var i = 0u; i < lightSet.numLights; i = i + 1) {
        if (lightCount >= ${maxLightsPerCluster}) {
            break;
        }

        if (!doesLightIntersectCluster(lightSet.lights[i].pos, minBounds32f, maxBounds32f)) {
            continue;
        }

        clusterSet.clusters[clusterIndex].lightIndices[lightCount] = i;
        lightCount = lightCount + 1;
    }

    clusterSet.clusters[clusterIndex].lightCount = lightCount;
}