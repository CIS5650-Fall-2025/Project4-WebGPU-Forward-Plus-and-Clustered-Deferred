@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;

@group(${bindGroup_model}) @binding(0) var<storage, read_write> lightSet: LightSet;
@group(${bindGroup_model}) @binding(1) var<storage, read_write> clusterSet: ClusterSet;

// Constants
const NUM_CLUSTERS_X: u32 = 16;
const NUM_CLUSTERS_Y: u32 = 9;
const NUM_CLUSTERS_Z: u32 = 24;
const MAX_LIGHTS_PER_CLUSTER: u32 = 100;

fn screenSpaceToViewSpace(x: f32, y: f32, z: f32) -> vec3f {
    let screenPos = vec4f(x, y, z, 1.0);
    let viewPos = camera.inverseViewProjMat * screenPos;
    return viewPos.xyz / viewPos.w;
}

@compute
@workgroup_size(${moveLightsWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterX: u32 = globalIdx.x;
    let clusterY: u32 = globalIdx.y;
    let clusterZ: u32 = globalIdx.z;

    // Calculate cluster bounds in screen space 2D
    let screenMinX: f32 = f32(clusterX) / f32(NUM_CLUSTERS_X) * camera.screenSize.x;
    let screenMaxX: f32 = f32(clusterX + 1) / f32(NUM_CLUSTERS_X) * camera.screenSize.x;
    let screenMinY: f32 = f32(clusterY) / f32(NUM_CLUSTERS_Y) * camera.screenSize.y;
    let screenMaxY: f32 = f32(clusterY + 1) / f32(NUM_CLUSTERS_Y) * camera.screenSize.y;

    // Calculate depth bounds for the cluster (Z direction)
    let zNear: f32 = camera.near * pow(camera.far / camera.near, f32(clusterZ) / f32(NUM_CLUSTERS_Z));
    let zFar: f32 = camera.near * pow(camera.far / camera.near, f32(clusterZ + 1) / f32(NUM_CLUSTERS_Z));

    // Convert screen-space bounds to view space
    let viewMin = screenSpaceToViewSpace(screenMinX, screenMinY, zNear);
    let viewMax = screenSpaceToViewSpace(screenMaxX, screenMaxY, zFar);

    // Create AABB for the cluster
    let clusterAABBMin = min(viewMin, viewMax);
    let clusterAABBMax = max(viewMin, viewMax);

    // Initialize light count for this cluster
    let clusterIndex = clusterZ * NUM_CLUSTERS_X * NUM_CLUSTERS_Y + clusterY * NUM_CLUSTERS_X + clusterX;
    clusterSet.numLights[clusterIndex] = 0;

    // Check light-cluster intersection and add lights to the cluster
    for (var i: u32 = 0; i < lightSet.numLights; i++) {
        let light = lightSet.lights[i];

        // Check if the light's sphere intersects the cluster's AABB
        let lightAABBMin = light.pos - vec3f(${lightRadius});
        let lightAABBMax = light.pos + vec3f(${lightRadius});

        if (clusterAABBMax.x > lightAABBMin.x && clusterAABBMin.x < lightAABBMax.x &&
            clusterAABBMax.y > lightAABBMin.y && clusterAABBMin.y < lightAABBMax.y &&
            clusterAABBMax.z > lightAABBMin.z && clusterAABBMin.z < lightAABBMax.z) {

            let lightCount = clusterSet.numLights[clusterIndex];
            if (lightCount < MAX_LIGHTS_PER_CLUSTER) {
                clusterSet.lightIndices[clusterIndex][lightCount] = i;
                clusterSet.numLights[clusterIndex] += 1;
            }
        }
    }
}

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
