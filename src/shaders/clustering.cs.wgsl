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

const clusterCountX = ${clusterCountX};
const clusterCountY = ${clusterCountY};
const clusterCountZ = ${clusterCountZ};

const numClusters = clusterCountX * clusterCountY * clusterCountZ;
const maxLightsPerCluster = ${maxLightsPerCluster};

@group(${bindGroup_scene}) @binding(0) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(1) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterLights: array<u32>;

@compute
@workgroup_size(4, 4, 4)
fn main(@builtin(global_invocation_id) global_id: vec3u) {
    if (global_id.x >= clusterCountX || global_id.y >= clusterCountY || global_id.z >= clusterCountZ) {
        return;
    }

    let clusterId = global_id;
    let clusterIdx = global_id.x + global_id.y * clusterCountX + global_id.z * clusterCountX * clusterCountY;
    let clusterOffset = clusterIdx * (1u + maxLightsPerCluster);
    
    // Initialize numLights to 0
    clusterLights[clusterOffset] = 0u;
    // 0.1
    let clusterSizeX = cameraUniforms.screenWidth / f32(clusterCountX);
    let clusterSizeY = cameraUniforms.screenHeight / f32(clusterCountY);
    // Cluster x y range in [0, 1]
    let xMin = f32(clusterId.x) * clusterSizeX;
    let xMax = f32(clusterId.x + 1u) * clusterSizeX;
    let yMin = f32(clusterId.y) * clusterSizeY;
    let yMax = f32(clusterId.y + 1u) * clusterSizeY;
    
    // Convert screen-space to NDC (-1, 1)
    let ndcMin = vec2f(xMin / cameraUniforms.screenWidth * 2.0 - 1.0, yMin / cameraUniforms.screenHeight * 2.0 - 1.0);
    let ndcMax = vec2f(xMax / cameraUniforms.screenWidth * 2.0 - 1.0, yMax / cameraUniforms.screenHeight * 2.0 - 1.0);

    // let clusterDepthSlice = 1000 / f32(clusterCountZ);
    let clusterDepthSlice = (cameraUniforms.farPlane - cameraUniforms.nearPlane) / f32(clusterCountZ);

    // nearest z for this cluster
    let zNear = cameraUniforms.nearPlane + f32(clusterId.z) * clusterDepthSlice;
    // farest z
    let zFar = cameraUniforms.nearPlane + f32(clusterId.z + 1u) * clusterDepthSlice;

    // Compute frustum corners in view space
    var frustumCorners: array<vec3f, 8>;

    let invProjMat = cameraUniforms.invProjMat;

    var ndcPoints = array<vec4f, 8>(
        vec4f(ndcMin.x, ndcMin.y, -1.0, 1.0),
        vec4f(ndcMax.x, ndcMin.y, -1.0, 1.0),
        vec4f(ndcMin.x, ndcMax.y, -1.0, 1.0),
        vec4f(ndcMax.x, ndcMax.y, -1.0, 1.0),
        vec4f(ndcMin.x, ndcMin.y, 1.0, 1.0),
        vec4f(ndcMax.x, ndcMin.y, 1.0, 1.0),
        vec4f(ndcMin.x, ndcMax.y, 1.0, 1.0),
        vec4f(ndcMax.x, ndcMax.y, 1.0, 1.0)
    );

    for (var i = 0u; i < 8u; i = i + 1u) {
        var corner = ndcPoints[i];
        corner.z = mix(-zNear / cameraUniforms.farPlane, -zFar / cameraUniforms.farPlane, corner.z * 0.5 + 0.5);
        var viewSpaceCorner = invProjMat * corner;
        //var viewSpaceCorner = cameraUniforms.invViewProjMat * corner;
        viewSpaceCorner = viewSpaceCorner / viewSpaceCorner.w;
        frustumCorners[i] = viewSpaceCorner.xyz;
    }

    // Compute AABB of cluster in view space
    var clusterMin = frustumCorners[0];
    var clusterMax = frustumCorners[0];
    for (var i = 1u; i < 8u; i = i + 1u) {
        clusterMin = min(clusterMin, frustumCorners[i]);
        clusterMax = max(clusterMax, frustumCorners[i]);
    }

    // Assign lights to clusters
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx = lightIdx + 1u) {
        let light = lightSet.lights[lightIdx];
        let radius = f32(${lightRadius});

        // Light bounding sphere
        let lightPos = (cameraUniforms.viewMat * vec4f(light.pos, 1.0)).xyz;
        let sphereMin = lightPos - vec3f(radius);
        let sphereMax = lightPos + vec3f(radius);

        // Check intersection between cluster AABB and light sphere AABB
        let intersectMin = max(clusterMin, sphereMin);
        let intersectMax = min(clusterMax, sphereMax);
        let overlaps = all(intersectMin <= intersectMax);

        if (overlaps) {
            let numLights = clusterLights[clusterOffset];
            if (numLights < maxLightsPerCluster) {
                clusterLights[clusterOffset + 1u + numLights] = lightIdx;
                clusterLights[clusterOffset] = numLights + 1u;
            }
        }
    }
}