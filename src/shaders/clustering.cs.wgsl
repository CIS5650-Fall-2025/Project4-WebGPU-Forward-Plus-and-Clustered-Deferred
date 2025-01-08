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

// From GamePhysicsCookbook
// https://github.com/gszauer/GamePhysicsCookbook/blob/master/Code/Geometry3D.cpp#L149
fn intersectionAABBSphere(center: vec3f, bboxMin: vec3f, bboxMax: vec3f) -> bool {
    let closestPoint = clamp(center, bboxMin, bboxMax);
    let closestVector = center - closestPoint;
    let squaredDistance = dot(closestVector, closestVector);
    return squaredDistance <= ${lightRadius ** 2};
}

@compute @workgroup_size(${clusterWorkgroupSize})
fn main(@builtin(global_invocation_id) globalIdx: vec3u, @builtin(num_workgroups) numWorkgropus: vec3u) {
    if (globalIdx.x >= clusterSet.numClusters.x ||
        globalIdx.y >= clusterSet.numClusters.y ||
        globalIdx.z >= clusterSet.numClusters.z) {
            return;
    }

    let clusterIdx = calculateClusterIdx(globalIdx, clusterSet.numClusters);

    // Ratio far plane / near plane
    let clipPlaneRatio = cameraUniforms.clipPlanes[1] / cameraUniforms.clipPlanes[0];

    // Exponential z-spacing from https://www.aortiz.me/2018/12/21/CG.html#part-2
    // negative z-direction!
    let zNearView = - cameraUniforms.clipPlanes[0] * pow(clipPlaneRatio, f32(globalIdx.z)     / f32(clusterSet.numClusters.z));
    let zFarView  = - cameraUniforms.clipPlanes[0] * pow(clipPlaneRatio, f32(globalIdx.z + 1) / f32(clusterSet.numClusters.z));

    // Compute w-coordinate in clip space to scale x- and y-coordinates
    let wNearClip = zNearView * cameraUniforms.projMat[2][3];
    let wFarClip  = zFarView  * cameraUniforms.projMat[2][3];

    // Get x- and y-coordinate in NDC space
    let xMinNDC = 2 * f32(globalIdx.x)     / f32(clusterSet.numClusters.x) - 1;
    let xMaxNDC = 2 * f32(globalIdx.x + 1) / f32(clusterSet.numClusters.x) - 1;
    let yMinNDC = 2 * f32(globalIdx.y)     / f32(clusterSet.numClusters.y) - 1;
    let yMaxNDC = 2 * f32(globalIdx.y + 1) / f32(clusterSet.numClusters.y) - 1;

    // Undo perspective projection
    // Depending on quadrant, the coordinate of the closer or further plane of the frustrum determines the bounding box
    var xMinClip: f32;
    var xMaxClip: f32;
    var yMinClip: f32;
    var yMaxClip: f32;
    if (xMinNDC < 0) { xMinClip = xMinNDC * wFarClip;  }
    else             { xMinClip = xMinNDC * wNearClip; }
    if (xMaxNDC < 0) { xMaxClip = xMaxNDC * wNearClip; }
    else             { xMaxClip = xMaxNDC * wFarClip;  }
    if (yMinNDC < 0) { yMinClip = yMinNDC * wFarClip;  }
    else             { yMinClip = yMinNDC * wNearClip; }
    if (yMaxNDC < 0) { yMaxClip = yMaxNDC * wNearClip; }
    else             { yMaxClip = yMaxNDC * wFarClip;  }

    // Go from clip to view space
    let invProjVec = vec2f(1 / cameraUniforms.projMat[0][0], 1 / cameraUniforms.projMat[1][1]);
    let xyMinView = vec2f(xMinClip, yMinClip) * invProjVec;
    let xyMaxView = vec2f(xMaxClip, yMaxClip) * invProjVec;

    // Final bounding box position in view space (z is negative!)
    let bboxMin = vec3f(xyMinView, zFarView);
    let bboxMax = vec3f(xyMaxView, zNearView);

    let cluster = &clusterSet.clusters[clusterIdx];
    var count = 0u;
    for (var i = 0u; i < lightSet.numLights; i++) {
        let light = &lightSet.lights[i];

        // Get light position in view space
        let lightViewPos = cameraUniforms.viewMat * vec4((*light).pos, 1);
        
        // Check for intersection and add to cluster if applicable
        if (intersectionAABBSphere(lightViewPos.xyz, bboxMin, bboxMax)) {
            (*cluster).lightIndices[count] = i;
            count++;

            if (count >= ${maxLightsPerCluster}) {
                break;
            }
        }
    }

    (*cluster).numLights = count;
}