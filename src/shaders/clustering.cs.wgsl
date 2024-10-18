// TODO-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

@group(${bindGroup_scene}) @binding(0) var<uniform> inverseProjMat: mat4x4f;
@group(${bindGroup_scene}) @binding(1) var<uniform> inverseViewMat: mat4x4f;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(3) var<storage, read_write> clusterSet: array<Cluster>;

const clusterPerDim = 16u;
const maxLightsPerCluster = 200;

@compute
@workgroup_size(${moveLightsWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterIdx = globalIdx.x;
    if (clusterIdx >= clusterPerDim * clusterPerDim * clusterPerDim) {
        return;
    }
    // find cluster indx in 3D
    let x_idx = f32(clusterIdx % clusterPerDim);
    let y_idx = f32((clusterIdx / clusterPerDim) % clusterPerDim);
    let z_idx = f32(clusterIdx / (clusterPerDim * clusterPerDim));

    // transform to % of screen size
    let minX = x_idx / f32(clusterPerDim);
    let maxX = (x_idx + 1.0) / f32(clusterPerDim);
    let minY = y_idx / f32(clusterPerDim);
    let maxY = (y_idx + 1.0) / f32(clusterPerDim);
    let minZ = z_idx / f32(clusterPerDim);
    let maxZ = (z_idx + 1.0) / f32(clusterPerDim);

    let minWorld = convertToWorldSpace(minX, minY, minZ);
    let maxWorld = convertToWorldSpace(maxX, maxY, maxZ);

    // find the lights that are inside the cluster
    clusterSet[clusterIdx].numLights = 0;
    for (var i = 0u; i < lightSet.numLights; i++) {    
        let light = lightSet.lights[i];
        if (light.pos.x >= minWorld.x && light.pos.x <= maxWorld.x &&
            light.pos.y >= minWorld.y && light.pos.y <= maxWorld.y &&
            light.pos.z >= minWorld.z && light.pos.z <= maxWorld.z) {
            let count = clusterSet[clusterIdx].numLights;
            if (count < maxLightsPerCluster) {
                clusterSet[clusterIdx].lightIndices[count] = i;
                clusterSet[clusterIdx].numLights += 1;
            }
        }
    }
}

fn convertToWorldSpace(x: f32, y: f32, z: f32) -> vec3f {
    var ndc = vec3f(x * 2.0 - 1.0, 1.0 - y * 2.0, z);
    // flip y according to ed
    // ndc.y *= -1.0;

    let clip_coord = vec4f(ndc, 1.0);
    var view_coord = inverseProjMat * clip_coord;

    view_coord /= view_coord.w;

    let world_coord = inverseViewMat * view_coord;
    return world_coord.xyz;
}

