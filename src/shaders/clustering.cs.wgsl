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

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

@compute @workgroup_size(16, 9, 1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    if (global_id.x >= clusterSet.numClustersX ||
        global_id.y >= clusterSet.numClustersY || 
        global_id.z >= clusterSet.numClustersZ) {
        return;
    }
    
    // Calculating cluster index
    let clusterIndex = global_id.x + 
                       global_id.y * clusterSet.numClustersX + 
                       global_id.z * clusterSet.numClustersX * clusterSet.numClustersY;

    // ------------------------------------
    // Calculating cluster bounds:
    // ------------------------------------

    // - Calculate the screen-space bounds for this cluster in 2D (XY).
    let epsilon = 0.0001;
    let clusterSizeX = 2.0 / f32(clusterSet.numClustersX);
    let clusterSizeY = 2.0 / f32(clusterSet.numClustersY);
    let minX = -1.0 + f32(global_id.x) * clusterSizeX;
    let minY = -1.0 + f32(global_id.y) * clusterSizeY;
    let maxX = min(minX + clusterSizeX, 1.0 - epsilon);
    let maxY = min(minY + clusterSizeY, 1.0 - epsilon);

    // - Calculate the depth bounds for this cluster in Z (near and far planes).
    let zNear = cameraUniforms.nearPlane;
    let zFar = cameraUniforms.farPlane;
    let clusterSizeZ = 1.0 / f32(clusterSet.numClustersZ);
    let minZ = f32(global_id.z) * clusterSizeZ;
    let maxZ = minZ + clusterSizeZ;

    // - Convert these screen and depth bounds into view-space coordinates.
    let ndcCorners = array<vec4<f32>, 8>(
        vec4<f32>(minX, minY, minZ, 1.0),
        vec4<f32>(maxX, minY, minZ, 1.0),
        vec4<f32>(minX, maxY, minZ, 1.0),
        vec4<f32>(maxX, maxY, minZ, 1.0),
        vec4<f32>(minX, minY, maxZ, 1.0),
        vec4<f32>(maxX, minY, maxZ, 1.0),
        vec4<f32>(minX, maxY, maxZ, 1.0),
        vec4<f32>(maxX, maxY, maxZ, 1.0)
    );

    var viewCorners = array<vec3<f32>, 8>();
    for (var i = 0u; i < 8u; i++) {
        // Unproject from NDC to view space
        let viewPos = cameraUniforms.invProjMat * ndcCorners[i];
        viewCorners[i] = viewPos.xyz / viewPos.w;
    }

    // Calculate AABB in view space
    var minPoint = viewCorners[0];
    var maxPoint = viewCorners[0];
    for (var i = 1u; i < 8u; i++) {
        minPoint = min(minPoint, viewCorners[i]);
        maxPoint = max(maxPoint, viewCorners[i]);
    }

    // Store the AABB in the clusterSet
    clusterSet.clusters[clusterIndex].minBounds = minPoint;
    clusterSet.clusters[clusterIndex].maxBounds = maxPoint;

    // ------------------------------------
    // Assigning lights to clusters:
    // ------------------------------------

    // Initialize a counter for the number of lights in this cluster.
    var lightCount: u32 = 0u;

    // For each light
    for (var i: u32 = 0u; i < lightSet.numLights; i++) {
        let light = lightSet.lights[i];
        let lightViewSpace = cameraUniforms.viewMat * vec4f(light.pos,1.0);
        // Check if the light intersects with the cluster's bounding box (AABB)
        if (sphereIntersectsAABB(lightViewSpace.xyz, ${lightRadius}, minPoint, maxPoint)) {
            // If it intersects, add it to the cluster's light list
            if (lightCount < ${maxLightPerCluster}) {
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

fn projectPointToNDC(viewPos: vec3<f32>, projMat: mat4x4<f32>) -> vec4<f32> {
    let clipPos = projMat * vec4<f32>(viewPos, 1.0);
    return clipPos / clipPos.w;
}

fn sphereIntersectsAABB(sphereCenter: vec3<f32>, sphereRadius: f32, aabbMin: vec3<f32>, aabbMax: vec3<f32>) -> bool {
    // For simplicity, assume the frustrum is a cube instead of frustrum
    let closestPoint = clamp(sphereCenter, aabbMin, aabbMax);
    let distance = length(sphereCenter - closestPoint);
    return distance <= sphereRadius;
}

fn unprojectPoint(point: vec4<f32>, invViewProj: mat4x4<f32>) -> vec3<f32> {
    let view = invViewProj * point;
    return view.xyz / view.w;
}