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

@group(${bindGroup_scene}) @binding(0) var<storage, read> lightSet: LightSet;

@group(${bindGroup_scene}) @binding(1) var<storage, read_write> clusters: array<Cluster>;

@group(${bindGroup_scene}) @binding(2) var<uniform> clusterGrid: ClusterGridMetadata;

@group(${bindGroup_scene}) @binding(3) var<uniform> cameraData: CameraUniforms;

struct AABB {
    min: vec3<f32>,
    max: vec3<f32>,
};

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) global_id: vec3<u32>) {
    let clusterX = global_id.x;
    let clusterY = global_id.y;
    let clusterZ = global_id.z;

    var clusterIndex = clusterX + clusterY * clusterGrid.clusterGridSizeX + clusterZ * clusterGrid.clusterGridSizeX * clusterGrid.clusterGridSizeY;

    clusters[clusterIndex].numLights = 0;

    let bounds = calculateClusterScreenBounds(clusterX, clusterY, clusterZ, clusterIndex);

    let aabbMin = bounds.min;
    let aabbMax = bounds.max;

    for (var i = 0u; i < lightSet.numLights; i++) {
        let light = lightSet.lights[i];
        // recordDistanceLightCluster(light, aabbMin, aabbMax, clusterIndex, i);

        if (lightIntersectsCluster(light, aabbMin, aabbMax)) {
            if (clusters[clusterIndex].numLights < clusterGrid.maxLightsPerCluster) {
                clusters[clusterIndex].lightIndices[clusters[clusterIndex].numLights] = i;
                clusters[clusterIndex].numLights = clusters[clusterIndex].numLights + 1;
            }
        }
    }
}

fn recordDistanceLightCluster(light: Light, aabbMin: vec3<f32>, aabbMax: vec3<f32>, clusterIndex: u32, index: u32) {
    let closestPoint = clamp(light.pos, aabbMin, aabbMax);
    
    let distance = length(light.pos - closestPoint);

    clusters[clusterIndex].lightIndices[index] = u32(distance);
}

fn calculateClusterScreenBounds(clusterX: u32, clusterY: u32, clusterZ: u32, clusterIndex: u32) -> AABB {
    let clusterWidthNDC = 2.0 / f32(clusterGrid.clusterGridSizeX);
    let clusterHeightNDC = 2.0 / f32(clusterGrid.clusterGridSizeY);

    let minXNDC = -1.0 + clusterWidthNDC * f32(clusterX);
    let minYNDC = -1.0 + clusterHeightNDC * f32(clusterY);

    let depthMin = calculateDepthFromZIndex(clusterZ);
    let depthMax = calculateDepthFromZIndex(clusterZ + 1);

    let ndcMin = vec4<f32>(minXNDC, minYNDC, depthMin, 1.0);
    let ndcMax = vec4<f32>(minXNDC + clusterWidthNDC, minYNDC + clusterHeightNDC, depthMax, 1.0);

    let transformedMin = cameraData.invViewProjMat * ndcMin;
    let transformedMax = cameraData.invViewProjMat * ndcMax;

    let aabbMin = transformedMin.xyz / transformedMin.w;
    let aabbMax = transformedMax.xyz / transformedMax.w;

    return AABB(aabbMin, aabbMax);
}

fn calculateDepthFromZIndex(clusterZ: u32) -> f32 {
    let logZRatio = log2(cameraData.zFar / cameraData.zNear);
    let clusterDepthSize = logZRatio / f32(clusterGrid.clusterGridSizeZ);
    return cameraData.zNear * exp2(clusterDepthSize * f32(clusterZ));
}

fn lightIntersectsCluster(light: Light, aabbMin: vec3<f32>, aabbMax: vec3<f32>) -> bool {
    let closestPoint = clamp(light.pos, aabbMin, aabbMax);
    
    let distance = length(light.pos - closestPoint);

    return distance <= ${lightRadius};
}