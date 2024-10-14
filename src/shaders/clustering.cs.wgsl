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
fn distanceSquared(a: vec3<f32>, b: vec3<f32>) -> f32 {
    let diff = a - b;
    return dot(diff, diff);
}
fn isLightInCluster(lightPos: vec3<f32>, lightRadius: f32, minBounds: vec3<f32>, maxBounds: vec3<f32>) -> bool {
    var closestPoint: vec3<f32>;
    
    
    closestPoint.x = clamp(lightPos.x, minBounds.x, maxBounds.x);
    closestPoint.y = clamp(lightPos.y, minBounds.y, maxBounds.y);
    closestPoint.z = clamp(lightPos.z, minBounds.z, maxBounds.z);
    
    
    let distSq = distanceSquared(lightPos, closestPoint);

    
    return distSq <= (lightRadius * lightRadius);
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

    let zStepNDC = 2.0 / f32(clusterGridSize.z); 
    let clusterMinZNDC = -1.0 + f32(clusterZ) * zStepNDC;
    let clusterMaxZNDC = clusterMinZNDC + zStepNDC;

    var viewMin = camera.invProjMat * vec4<f32>(ndcMin.x, ndcMin.y, clusterMinZNDC, 1.0);
    var viewMax = camera.invProjMat * vec4<f32>(ndcMax.x, ndcMax.y, clusterMaxZNDC, 1.0);

    let viewMinCart = viewMin / viewMin.w;
    let viewMaxCart = viewMax / viewMax.w;

    cluster.minDepth = viewMinCart.xyz;
    cluster.maxDepth = viewMaxCart.xyz;
    cluster.numLights = 0u;

    let maxLightsPerCluster = 1032u;
    var lightCount = 0u;
    let lightRadius = f32(${lightRadius}); 

    for (var i = 0u; i < lightSet.numLights; i++) {
        
        let light = lightSet.lights[i];
        let lightPos = light.pos;
        

        if (isLightInCluster(lightPos, lightRadius, cluster.minDepth, cluster.maxDepth)) {
            if (lightCount < maxLightsPerCluster) {
                cluster.lightIndices[lightCount] = i;
                lightCount++;
            }
        }
    }
    cluster.numLights = lightCount;
    clusterSet.clusters[clusterIndex] = cluster;
}
