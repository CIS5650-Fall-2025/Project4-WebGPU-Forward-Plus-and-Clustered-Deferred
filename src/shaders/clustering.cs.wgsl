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


@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

fn sqDistPointAABB(_point: vec3<f32>, minAABB: vec3<f32>, maxAABB: vec3<f32>) -> f32 {
    var sqDist = 0.0;

    // Iterate over each dimension to calculate squared distance
    for (var i = 0; i < 3; i = i + 1) {
        let v = _point[i];
        if (v < minAABB[i]) {
            sqDist = sqDist + (minAABB[i] - v) * (minAABB[i] - v);
        }
        if (v > maxAABB[i]) {
            sqDist = sqDist + (v - maxAABB[i]) * (v - maxAABB[i]);
        }
    }

    return sqDist;
}


@compute @workgroup_size(${WORKGROUP_SIZE_X},${WORKGROUP_SIZE_Y},${WORKGROUP_SIZE_Z})
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let clusterX = global_id.x;
    let clusterY = global_id.y;
    let clusterZ = global_id.z;

    if (clusterX >= camera.clusterGridSize.x ||
        clusterY >= camera.clusterGridSize.y ||
        clusterZ >= camera.clusterGridSize.z) {
        return;
    }
    let clusterGridSize = camera.clusterGridSize;
    let canvasResolution = camera.canvasResolution;
    let clusterIndex = clusterZ * clusterGridSize.x * clusterGridSize.y + clusterY * clusterGridSize.x + clusterX;
    var cluster: Cluster;

    let screenMin = vec2<f32>(
        f32(clusterX) * (canvasResolution.x / f32(clusterGridSize.x)),
        f32(clusterY) * (canvasResolution.y / f32(clusterGridSize.y))
    );

    let screenMax = vec2<f32>(
        (f32(clusterX) + 1.0) * (canvasResolution.x / f32(clusterGridSize.x)),
        (f32(clusterY) + 1.0) * (canvasResolution.y / f32(clusterGridSize.y))
    );

    let ndcMin = vec2<f32>(
        (screenMin.x / canvasResolution.x) * 2.0 - 1.0,
        (screenMin.y / canvasResolution.y) * 2.0 - 1.0
    );
    let ndcMax = vec2<f32>(
        (screenMax.x / canvasResolution.x) * 2.0 - 1.0,
        (screenMax.y / canvasResolution.y) * 2.0 - 1.0
    );

    var viewMin = camera.invProjMat * vec4<f32>(ndcMin.x, ndcMin.y, camera.nearPlane, 1.0);
    var viewMax = camera.invProjMat * vec4<f32>(ndcMax.x, ndcMax.y, camera.nearPlane, 1.0);

    let viewMinCart = viewMin.xyz / viewMin.w;
    let viewMaxCart = viewMax.xyz / viewMax.w;


    let Zstep = (camera.farPlane - camera.nearPlane)/f32(clusterGridSize.z);
    let clusterMinZ = camera.nearPlane + f32(clusterZ)*Zstep;
    let clusterMaxZ = clusterMinZ + Zstep ;


    cluster.minDepth = vec3<f32>(viewMin.x, viewMin.y, clusterMinZ);
    cluster.maxDepth = vec3<f32>(viewMax.x, viewMax.y, clusterMaxZ);
    
    let maxLightsPerCluster = 1032u;
    var lightCount = 0u;
    let lightRadius = f32(${lightRadius}); 

    for (var i = 0u; i < lightSet.numLights; i++) {
        
        let light = lightSet.lights[i];
        let lightPos = camera.viewProjMat * vec4<f32>(light.pos, 1.0);
        
        let sqdis = sqDistPointAABB(lightPos.xyz, cluster.minDepth, cluster.maxDepth);
        if (sqdis < (lightRadius * lightRadius)) {
            if (lightCount < maxLightsPerCluster) {
                cluster.lightIndices[lightCount] = i;
                lightCount++;
            }
        }
    }
    cluster.numLights = 3;
    clusterSet.clusters[clusterIndex] = cluster;
}
