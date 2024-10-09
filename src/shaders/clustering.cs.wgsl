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

@group(0) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(1) var<storage, read> lightSet: LightSet;
@group(0) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    // Calculating cluster index
    let clusterIndex = global_id.x + 
                       global_id.y * clusterSet.numClustersX + 
                       global_id.z * clusterSet.numClustersX * clusterSet.numClustersY;

    // ------------------------------------
    // Calculating cluster bounds:
    // ------------------------------------

    // - Calculate the screen-space bounds for this cluster in 2D (XY).
    let clusterSizeX = 2.0 / f32(clusterSet.numClustersX);
    let clusterSizeY = 2.0 / f32(clusterSet.numClustersY);
    let minX = -1.0 + f32(global_id.x) * clusterSizeX;
    let minY = -1.0 + f32(global_id.y) * clusterSizeY;
    let maxX = minX + clusterSizeX;
    let maxY = minY + clusterSizeY;

    // - Calculate the depth bounds for this cluster in Z (near and far planes).
    let zNear = cameraUniforms.nearPlane;
    let zFar = cameraUniforms.farPlane;
    let clusterSizeZ = f32(clusterSet.numClustersZ);
    // 对数深度分布z(for now...?)
    let zSlice = f32(global_id.z);
    let nearDepth = zNear * pow(zFar / zNear, zSlice / clusterSizeZ);
    let farDepth = zNear * pow(zFar / zNear, (zSlice + 1.0) / clusterSizeZ);

    // - Convert these screen and depth bounds into view-space coordinates.
    let invViewProj = cameraUniforms.invViewProjMat;
    let nearBottomLeft = unprojectPoint(vec3(minX, minY, nearDepth), invViewProj);
    let nearBottomRight = unprojectPoint(vec3(maxX, minY, nearDepth), invViewProj);
    let nearTopLeft = unprojectPoint(vec3(minX, maxY, nearDepth), invViewProj);
    let nearTopRight = unprojectPoint(vec3(maxX, maxY, nearDepth), invViewProj);
    let farBottomLeft = unprojectPoint(vec3(minX, minY, farDepth), invViewProj);
    let farBottomRight = unprojectPoint(vec3(maxX, minY, farDepth), invViewProj);
    let farTopLeft = unprojectPoint(vec3(minX, maxY, farDepth), invViewProj);
    let farTopRight = unprojectPoint(vec3(maxX, maxY, farDepth), invViewProj);

    // - Store the computed bounding box (AABB) for the cluster.
    let minPoint = min(min(min(nearBottomLeft, nearBottomRight), min(nearTopLeft, nearTopRight)),
                    min(min(farBottomLeft, farBottomRight), min(farTopLeft, farTopRight)));

    let maxPoint = max(max(max(nearBottomLeft, nearBottomRight), max(nearTopLeft, nearTopRight)),
                    max(max(farBottomLeft, farBottomRight), max(farTopLeft, farTopRight)));

    // Store the AABB in the clusterSet
    clusterSet.clusters[clusterIndex].minBounds = minPoint;
    clusterSet.clusters[clusterIndex].maxBounds = maxPoint;

    // ------------------------------------
    // Assigning lights to clusters:
    // ------------------------------------

    // Initialize a counter for the number of lights in this cluster.
    var lightCount: u32 = 0u;
    let lightRadius: f32 = 10.0;
    let maxLightsPerCluster: u32 = 256u; // Adjust this value as needed

    // For each light
    for (var i: u32 = 0u; i < lightSet.numLights; i++) {
        let light = lightSet.lights[i];
        
        // Check if the light intersects with the cluster's bounding box (AABB)
        if (sphereIntersectsAABB(light.pos, lightRadius, minPoint, maxPoint)) {
            // If it intersects, add it to the cluster's light list
            if (lightCount < maxLightsPerCluster) {
                clusterSet.clusters[clusterIndex].lightIndices[lightCount] = i;
                lightCount++;
            } else {
                // Stop adding lights if the maximum number of lights is reached
                break;
            }
        }
    }

    // Store the number of lights assigned to this cluster
    clusterSet.clusters[clusterIndex].lightCount = lightCount;
    
}

fn sphereIntersectsAABB(sphereCenter: vec3<f32>, sphereRadius: f32, aabbMin: vec3<f32>, aabbMax: vec3<f32>) -> bool {
    let closestPoint = clamp(sphereCenter, aabbMin, aabbMax);
    let distance = length(sphereCenter - closestPoint);
    return distance <= sphereRadius;
}

fn unprojectPoint(point: vec3<f32>, invViewProj: mat4x4<f32>) -> vec3<f32> {
    let clip = vec4(point, 1.0);
    let view = invViewProj * clip;
    return view.xyz / view.w;
}