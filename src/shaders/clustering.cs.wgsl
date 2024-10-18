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

@compute @workgroup_size(8, 8, 1)
fn main(@builtin(global_invocation_id) index: vec3u) {
    let idx = index.x +
              index.y * clusterSet.nx +
              index.z * clusterSet.nx * clusterSet.ny;
    
    // ----------------------
    // Compute cluster bounds
    // ----------------------
    // Prefetch and precomputations
    let zNear = cameraUniforms.nearClip;
    let zFar = cameraUniforms.farClip;
    let zIdx = f32(index.z);
    let nz = f32(clusterSet.nz);
    let invViewProjMat = cameraUniforms.invViewProjMat;
    let clusterDimX = 2.0 / f32(clusterSet.nx);
    let clusterDimY = 2.0 / f32(clusterSet.ny);

    // X and Y span in NDC of one cluster
    let minNdcX = -1.0 + f32(index.x) * clusterDimX;
    let minNdcY = -1.0 + f32(index.y) * clusterDimY;
    let maxNdcX = minNdcX + clusterDimX;
    let maxNdcY = minNdcY + clusterDimY;

    // Z span in NDC
    let minNdcZ = zNear * pow(zFar / zNear, zIdx / nz);
    let maxNdcZ = zNear * pow(zFar / zNear, (zIdx + 1.0) / nz);
    
    // Retrieve the world coordinates of the frustum
    let vtxLeftBottomNear : vec3f = ndcToWorld(minNdcX, minNdcY, minNdcZ, invViewProjMat);
    let vtxLeftTopNear : vec3f = ndcToWorld(minNdcX, maxNdcY, minNdcZ, invViewProjMat);
    let vtxRightBottomNear : vec3f = ndcToWorld(maxNdcX, minNdcY, minNdcZ, invViewProjMat);
    let vtxRightTopNear : vec3f = ndcToWorld(maxNdcX, maxNdcY, minNdcZ, invViewProjMat);
    let vtxLeftBottomFar : vec3f = ndcToWorld(minNdcX, minNdcY, maxNdcZ, invViewProjMat);
    let vtxLeftTopFar : vec3f = ndcToWorld(minNdcX, maxNdcY, maxNdcZ, invViewProjMat);
    let vtxRightBottomFar : vec3f = ndcToWorld(maxNdcX, minNdcY, maxNdcZ, invViewProjMat);
    let vtxRightTopFar : vec3f = ndcToWorld(maxNdcX, maxNdcY, maxNdcZ, invViewProjMat);

    // Simply get AABB of the frustum
    let aabbMinBounds = min(min(min(vtxLeftBottomFar, vtxLeftBottomNear),   min(vtxLeftTopFar, vtxLeftTopNear)), 
                           min(min(vtxRightBottomFar, vtxRightBottomNear), min(vtxRightTopFar, vtxRightTopNear)));
    let aabbMaxBounds = max(max(max(vtxLeftBottomFar, vtxLeftBottomNear),   max(vtxLeftTopFar, vtxLeftTopNear)), 
                           max(max(vtxRightBottomFar, vtxRightBottomNear), max(vtxRightTopFar, vtxRightTopNear)));

    // Add cluster to the set
    clusterSet.clusters[idx].minBounds = aabbMinBounds;
    clusterSet.clusters[idx].maxBounds = aabbMaxBounds;

    // ----------------------
    // Add lights to clusters
    // ----------------------
    let n: lightCount = 0;

    for (var i: u32 = 0; i < lightSet.numLights; i++) {
        let light: Light = lightSet[i];
        let pos = light.pos;
        if (lightCount >= ${maxLightInCluster}) { break; }
        if (sphereAABBIntersection(pos, ${lightRadius}, aabbMinBounds, aabbMaxBounds)) {
            clusterSet.clusters[idx].lightIndices[lightCount] = i;
            lightCount++;
        }
    }
    clusterSet.clusters[idx].numLights = lightCount;
}

fn sphereAABBIntersection(pos: vec3f, radius: f32, aabbMinBounds: vec3f, aabbMaxBounds: vec3f) -> bool {
    let neighborPos = clamp(pos, aabbMinBounds, aabbMaxBounds);
    let d = length(pos - neighborPos);
    return d <= radius;
}

fn ndcToWorld(x: f32, y: f32, z: f32, invViewProjMat: mat4x4f) -> vec3f {
    let ndc = vec4(x, y, z, 1.0);
    let world = invViewProjMat * ndc;
    return world.xyz / world.w;
}