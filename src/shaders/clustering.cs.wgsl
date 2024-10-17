// TODO-2: implement the light clustering compute shader
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

// Need:
// - viewProj matrix
// - screen size
// - near and far distances
// - cluster struct

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// Function to calculate the NDC z value using the projection matrix
fn convertDepthToNDCWithProjMatrix(depthView: f32) -> f32 {
    // Create a vec4 with the view-space depth value
    let viewSpacePos: vec4<f32> = vec4<f32>(0.0, 0.0, depthView, 1.0);

    // Multiply by the projection matrix to get the clip-space position
    let clipSpacePos: vec4<f32> = cameraUniforms.proj * viewSpacePos;

    // Perform the perspective divide (divide by w)
    // and return the NDC z value
    return clipSpacePos.z / clipSpacePos.w;
}

// Helper function to calculate frustum depth at slice k
// For the depth frustums (Z-axis), divide the space between the near and far planes logarithmically to maintain perspective accuracy:
fn calculateFrustumDepth(n: f32, f: f32, numOfSlices: f32, currentSlice: f32) -> f32 {
    let depthView: f32 = n * pow(f / n, currentSlice / numOfSlices);
    return convertDepthToNDCWithProjMatrix(depthView);
}

// fn calculateClusterBounds() -> ClusterSet {
//     let n = cameraUniforms.nearAndFar.x;
//     let f = cameraUniforms.nearAndFar.y;

//     var clusterSet: ClusterSet;
//     for (var i = 0u; i < CLUSTER_DIMENSIONS.x; i = i + 1u) {
//         for (var j = 0u; j < CLUSTER_DIMENSIONS.y; j = j + 1u) {
//             for (var k = 0u; k < CLUSTER_DIMENSIONS.z; k = k + 1u) {
//                 // Calculate screen-space NDC coordinates (normalized between -1 and 1)
//                 let ndcX_min: f32 = f32((i / CLUSTER_DIMENSIONS.x) * 2 - 1);
//                 let ndcX_max: f32 = f32(((i + 1) / CLUSTER_DIMENSIONS.x) * 2 - 1);
//                 let ndcY_min: f32 = f32((j / CLUSTER_DIMENSIONS.y) * 2 - 1);
//                 let ndcY_max: f32 = f32(((j + 1) / CLUSTER_DIMENSIONS.y) * 2 - 1);

//                 // Calculate the near and far depth for the current Z slice in NDC
//                 let zNear = calculateFrustumDepth(n, f, f32(CLUSTER_DIMENSIONS.z), f32(k));
//                 let zFar = calculateFrustumDepth(n, f, f32(CLUSTER_DIMENSIONS.z), f32(k + 1));

//                 // Define corner points in NDC space (4 near-plane corners, 4 far-plane corners)
//                 let ndcCorners: array<vec4<f32>, 8> = array<vec4<f32>, 8>(
//                     vec4<f32>(ndcX_min, ndcY_min, zNear, 1.0), // Near bottom-left
//                     vec4<f32>(ndcX_max, ndcY_min, zNear, 1.0), // Near bottom-right
//                     vec4<f32>(ndcX_min, ndcY_max, zNear, 1.0), // Near top-left
//                     vec4<f32>(ndcX_max, ndcY_max, zNear, 1.0), // Near top-right
//                     vec4<f32>(ndcX_min, ndcY_min, zFar, 1.0),  // Far bottom-left
//                     vec4<f32>(ndcX_max, ndcY_min, zFar, 1.0),  // Far bottom-right
//                     vec4<f32>(ndcX_min, ndcY_max, zFar, 1.0),  // Far top-left
//                     vec4<f32>(ndcX_max, ndcY_max, zFar, 1.0)   // Far top-right
//                 );

//                 // Transform NDC corners to view-space using the inverse view-projection matrix
//                 var viewSpaceCorners: array<vec3<f32>, 8>;

//                 for (var c: u32 = 0; c < 8; c = c + 1) {
//                     let transformedCorner: vec4<f32> = cameraUniforms.invProj * ndcCorners[c];

//                     // Perform perspective divide to get 3D coordinates in view space
//                     let w: f32 = transformedCorner.w;
//                     viewSpaceCorners[c] = vec3<f32>(
//                         transformedCorner.x / w,
//                         transformedCorner.y / w,
//                         transformedCorner.z / w
//                     );
//                 }

//                 // Find the min/max for x, y, z to create the bounding box
//                 var minCoors: vec3<f32> = vec3<f32>(1e10, 1e10, 1e10);
//                 var maxCoors: vec3<f32> = vec3<f32>(-1e10, -1e10, -1e10);

//                 for (var c: u32 = 0; c < 8; c = c + 1) {
//                     minCoors = vec3<f32>(
//                         min(minCoors.x, viewSpaceCorners[c].x),
//                         min(minCoors.y, viewSpaceCorners[c].y),
//                         min(minCoors.z, viewSpaceCorners[c].z)
//                     );
//                     maxCoors = vec3<f32>(
//                         max(maxCoors.x, viewSpaceCorners[c].x),
//                         max(maxCoors.y, viewSpaceCorners[c].y),
//                         max(maxCoors.z, viewSpaceCorners[c].z)
//                     );
//                 }

//                 let clusterIdx: u32 = i + j * CLUSTER_DIMENSIONS.x + k * CLUSTER_DIMENSIONS.x * CLUSTER_DIMENSIONS.y;
//                 // Initialize the Cluster and assign it to the array
//                 clusterSet.clusters[clusterIdx] = Cluster(
//                     vec2<f32>(ndcX_min, ndcY_min),    // screenSpaceBounds
//                     AABB(minCoors, maxCoors),         // viewSpaceBbox
//                     0u,                               // numLights
//                     // Initialize the lightIndices array with default values (0 in this case)
//                     array<u32, MAX_LIGHTS_PER_CLUSTER>()
//                 );
//             }
//         }
//     }

//     clusterSet.numOfClusters = CLUSTER_DIMENSIONS.x * CLUSTER_DIMENSIONS.y * CLUSTER_DIMENSIONS.z;
//     return clusterSet;
// }

fn calculateClusterBounds(i: u32, j: u32, k: u32) -> Cluster {
    let n = cameraUniforms.nearAndFar.x;
    let f = cameraUniforms.nearAndFar.y;

    // Calculate screen-space NDC coordinates (normalized between -1 and 1)
    let ndcX_min: f32 = f32((i / CLUSTER_DIMENSIONS.x) * 2 - 1);
    let ndcX_max: f32 = f32(((i + 1) / CLUSTER_DIMENSIONS.x) * 2 - 1);
    let ndcY_min: f32 = f32((j / CLUSTER_DIMENSIONS.y) * 2 - 1);
    let ndcY_max: f32 = f32(((j + 1) / CLUSTER_DIMENSIONS.y) * 2 - 1);

    // Calculate the near and far depth for the current Z slice in NDC
    let zNear = calculateFrustumDepth(n, f, f32(CLUSTER_DIMENSIONS.z), f32(k));
    let zFar = calculateFrustumDepth(n, f, f32(CLUSTER_DIMENSIONS.z), f32(k + 1));

    // Define corner points in NDC space (4 near-plane corners, 4 far-plane corners)
    let ndcCorners: array<vec4<f32>, 8> = array<vec4<f32>, 8>(
        vec4<f32>(ndcX_min, ndcY_min, zNear, 1.0), // Near bottom-left
        vec4<f32>(ndcX_max, ndcY_min, zNear, 1.0), // Near bottom-right
        vec4<f32>(ndcX_min, ndcY_max, zNear, 1.0), // Near top-left
        vec4<f32>(ndcX_max, ndcY_max, zNear, 1.0), // Near top-right
        vec4<f32>(ndcX_min, ndcY_min, zFar, 1.0),  // Far bottom-left
        vec4<f32>(ndcX_max, ndcY_min, zFar, 1.0),  // Far bottom-right
        vec4<f32>(ndcX_min, ndcY_max, zFar, 1.0),  // Far top-left
        vec4<f32>(ndcX_max, ndcY_max, zFar, 1.0)   // Far top-right
    );

    // Transform NDC corners to view-space using the inverse view-projection matrix
    var viewSpaceCorners: array<vec3<f32>, 8>;

    for (var c: u32 = 0; c < 8; c = c + 1) {
        let transformedCorner: vec4<f32> = cameraUniforms.invProj * ndcCorners[c];

        // Perform perspective divide to get 3D coordinates in view space
        let w: f32 = transformedCorner.w;
        viewSpaceCorners[c] = vec3<f32>(
            transformedCorner.x / w,
            transformedCorner.y / w,
            transformedCorner.z / w
        );
    }

    // Find the min/max for x, y, z to create the bounding box
    var minCoors: vec3<f32> = vec3<f32>(1e10, 1e10, 1e10);
    var maxCoors: vec3<f32> = vec3<f32>(-1e10, -1e10, -1e10);

    for (var c: u32 = 0; c < 8; c = c + 1) {
        minCoors = vec3<f32>(
            min(minCoors.x, viewSpaceCorners[c].x),
            min(minCoors.y, viewSpaceCorners[c].y),
            min(minCoors.z, viewSpaceCorners[c].z)
        );
        maxCoors = vec3<f32>(
            max(maxCoors.x, viewSpaceCorners[c].x),
            max(maxCoors.y, viewSpaceCorners[c].y),
            max(maxCoors.z, viewSpaceCorners[c].z)
        );
    }

    // Initialize the Cluster
    var cluster: Cluster = Cluster(
        vec2<f32>(ndcX_min, ndcY_min),    // screenSpaceBounds
        AABB(minCoors, maxCoors),         // viewSpaceBbox
        0u,                               // numLights
        // Initialize the lightIndices array with default values (0 in this case)
        array<u32, ${maxLightsPerCluster}u>()
    );
 

    return cluster;
}

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
// Utility function to compute the squared distance between two points
fn distance_squared(a: vec3<f32>, b: vec3<f32>) -> f32 {
    let diff: vec3<f32> = a - b;
    return dot(diff, diff);
}

fn sphere_intersects_aabb(sphere_center: vec3<f32>, sphere_radius: f32, box_min: vec3<f32>, box_max: vec3<f32>) -> bool {
    // Step 1: Find the closest point on the AABB to the sphere center
    var closest_point: vec3<f32> = vec3<f32>(
        clamp(sphere_center.x, box_min.x, box_max.x),
        clamp(sphere_center.y, box_min.y, box_max.y),
        clamp(sphere_center.z, box_min.z, box_max.z)
    );

    // Step 2: Calculate the squared distance from the sphere's center to the closest point
    let distance_squared: f32 = distance_squared(closest_point, sphere_center);

    // Step 3: Check if the distance is less than or equal to the radius squared
    return distance_squared <= (sphere_radius * sphere_radius);
}

const dimYTimesDimZ: u32 = CLUSTER_DIMENSIONS.y * CLUSTER_DIMENSIONS.z;
const dimYTimesDimZInv: f32 = 1.0 / f32(dimYTimesDimZ);
const dimZInv: f32 = 1.0 / f32(CLUSTER_DIMENSIONS.z);  // Pre-calculate inverse for CLUSTER_DIMENSIONS.z

@compute
@workgroup_size(${lightCluserWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    let clusterIdx: u32 = globalIdx.x;
    if (clusterIdx >= ${numOfClusters}) {
        return;
    }

    /**
     * Calculate the 3D index (i, j, k) from the 1D cluster index
     * This is the reverse operation of the 3D to 1D conversion
     */
    let clusterIdx_f32 = f32(clusterIdx);  // Convert clusterIdx to float once to avoid redundant casts
    // Replace division by multiplication with the inverse
    let i = u32(floor(clusterIdx_f32 * dimYTimesDimZInv));
    let remainder = clusterIdx - i * dimYTimesDimZ;  // Avoid another modulo by reusing the value of i
    let remainder_f32 = f32(remainder);  // Convert remainder to float once
    let j = u32(floor(remainder_f32 * dimZInv));  // Use inverse to replace division
    let k = remainder - j * CLUSTER_DIMENSIONS.z;  // Avoid another modulo by reusing the value of j
    /******************************************************************************/

    var cluster: Cluster = calculateClusterBounds(i, j, k);
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        if (cluster.numLights > ${maxLightsPerCluster}) {
            cluster.numLights = ${maxLightsPerCluster}; // Otherwise we'll exceed the array size
            break;
        }

        let viewSpaceLightPos: vec3<f32> = (cameraUniforms.view * vec4<f32>(lightSet.lights[lightIdx].pos, 1.0)).xyz;
        let curBbox: AABB = cluster.viewSpaceBbox;
        if (sphere_intersects_aabb(viewSpaceLightPos, ${lightRadius}, curBbox.min, curBbox.max)) {
            cluster.lightIndices[cluster.numLights] = lightIdx;
            cluster.numLights += 1u;
        }
    }

    clusterSet.clusters[clusterIdx] = cluster;
}
