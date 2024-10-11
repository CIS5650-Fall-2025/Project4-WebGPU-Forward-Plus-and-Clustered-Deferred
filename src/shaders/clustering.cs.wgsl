// TODO-2: implement the light clustering compute shader

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

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

fn applyTransform(p: vec4<f32>, transform: mat4x4<f32>) -> vec3<f32> {
    let transformed = transform * p;
    return transformed.xyz / transformed.w;
}

// https://stackoverflow.com/a/4579069
fn intersectionTest(S: vec3<f32>, r: f32, C1: vec3<f32>, C2: vec3<f32>) -> bool {
    var dist_squared = r * r;
    /* assume C1 and C2 are element-wise sorted, if not, do that now */
    if (S.x < C1.x) {
        dist_squared -= (S.x - C1.x) * (S.x - C1.x);
    }
    else if (S.x > C2.x) {
        dist_squared -= (S.x - C2.x) * (S.x - C2.x);
    }

    if (S.y < C1.y) {
        dist_squared -= (S.y - C1.y) * (S.y - C1.y);
    }
    else if (S.y > C2.y) {
        dist_squared -= (S.y - C2.y) * (S.y - C2.y);
    }

    if (S.z < C1.z) {
        dist_squared -= (S.z - C1.z) * (S.z - C1.z);
    }
    else if (S.z > C2.z) {
        dist_squared -= (S.z - C2.z) * (S.z - C2.z);
    }
    
    return dist_squared > 0.0;
    
    // let closestPoint = clamp(S, C1, C2);
    // let vecToClosestPoint = closestPoint - S;
    // let distanceSquared = dot(vecToClosestPoint, vecToClosestPoint);
    // return distanceSquared < dist_squared;
}

@compute
@workgroup_size(1,1,1)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    // For each cluster (X, Y, Z):
    let clusterIdx = globalIdx.x +
                    globalIdx.y * ${numClusterX} +
                    globalIdx.z * ${numClusterY} * ${numClusterX};
    if (clusterIdx >= ${numClusterX} * ${numClusterY} * ${numClusterZ}) {
        return;
    }
    // Calculate the screen-space bounds for this cluster in 2D (XY).
    let minX = -1.0 + f32(globalIdx.x) * 2.0 / f32(${numClusterX});
    let maxX = -1.0 + f32(globalIdx.x + 1) * 2.0 / f32(${numClusterX});
    let minY = -1.0 + f32(globalIdx.y) * 2.0 / f32(${numClusterY});
    let maxY = -1.0 + f32(globalIdx.y + 1) * 2.0 / f32(${numClusterY});

    // Calculate the depth bounds for this cluster in Z (near and far planes).
    let minZ = f32(globalIdx.z) / f32(${numClusterZ});
    let maxZ = f32(globalIdx.z + 1) / f32(${numClusterZ});

    // let ndcNear = vec4(minX,minY,-1,1);
    // let worldPosNear4 = cameraUniforms.projInv * ndcNear;
    // let worldPosNear = worldPosNear4.xyz / worldPosNear4.w;
    
    // let ndcFar = vec4(minX,minY,1,1);
    // let worldPosFar4 = cameraUniforms.projInv * ndcFar;
    // let worldPosFar = worldPosFar4.xyz / worldPosFar4.w;

    // let minZ = lerp(ndcNear, ndcFar, f32(globalIdx.z) / f32(numClusterZ));
    // let maxZ = lerp(ndcNear, ndcFar, f32(globalIdx.z + 1) / f32(numClusterZ));

    // Convert these screen and depth bounds into view-space coordinates.
    let lbn = applyTransform(vec4(minX, minY, minZ, 1.0), cameraUniforms.projInv);
    let lbf = applyTransform(vec4(minX, minY, maxZ, 1.0), cameraUniforms.projInv);
    let ltn = applyTransform(vec4(minX, maxY, minZ, 1.0), cameraUniforms.projInv);
    let ltf = applyTransform(vec4(minX, maxY, maxZ, 1.0), cameraUniforms.projInv);
    let rbn = applyTransform(vec4(maxX, minY, minZ, 1.0), cameraUniforms.projInv);
    let rbf = applyTransform(vec4(maxX, minY, maxZ, 1.0), cameraUniforms.projInv);
    let rtn = applyTransform(vec4(maxX, maxY, minZ, 1.0), cameraUniforms.projInv);
    let rtf = applyTransform(vec4(maxX, maxY, maxZ, 1.0), cameraUniforms.projInv);

    // Store the computed bounding box (AABB) for the cluster.
    clusterSet.clusters[clusterIdx].minBB = min(min(min(min(min(min(min(lbn, lbf), rbn), rbf), ltn), ltf), rtn), rtf);
    clusterSet.clusters[clusterIdx].maxBB = max(max(max(max(max(max(max(lbn, lbf), rbn), rbf), ltn), ltf), rtn), rtf);

    // Initialize a counter for the number of lights in this cluster.
    var numLights : u32 = 0u;

    // For each light:
    let r = f32(${lightRadius});
    for (var i: u32 = 0u; i < lightSet.numLights; i++) {
        let light = lightSet.lights[i];
        // Check if the light intersects with the cluster’s bounding box (AABB).
        if (intersectionTest(applyTransform(vec4(light.pos, 1.0), cameraUniforms.view), r, clusterSet.clusters[clusterIdx].minBB, clusterSet.clusters[clusterIdx].maxBB)) {
        // if (intersectionTest(light.pos, r, clusterSet.clusters[clusterIdx].minBB, clusterSet.clusters[clusterIdx].maxBB)) {
            // If it does, add the light to the cluster's light list.
            clusterSet.clusters[clusterIdx].lights[numLights] = i;
            numLights++;
        }
        // Stop adding lights if the maximum number of lights is reached.
        if (numLights >= ${maxNumLightsPerCluster}) {
            break;
        }
    }

    // Store the number of lights assigned to this cluster.
    clusterSet.clusters[clusterIdx].numLights = numLights;
}