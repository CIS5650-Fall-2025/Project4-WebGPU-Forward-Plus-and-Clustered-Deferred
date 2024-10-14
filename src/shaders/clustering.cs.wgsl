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
@group(${bindGroup_scene}) @binding(1) var<storage> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusters: array<Cluster>;

// FIXME: use non-uniform z?
fn to_ndc(idx: vec3f) -> vec3f {
    let xy_ndc = idx.xy * 2.0 / vec2f(${clusterX}, ${clusterY}) - 1.0;
    let z_ndc = idx.z / ${clusterZ};
    return vec3f(xy_ndc.x, xy_ndc.y, z_ndc);
}

fn intersect(c: vec3f, r: f32, minB: vec3f, maxB: vec3f) -> bool {
    var dist = 0.0;
    for (var i: u32 = 0u; i < 3; i++) {
        
        if (c[i] < minB[i]) {
            dist += (minB[i] - c[i]) * (minB[i] - c[i]);
        } else if (c[i] > maxB[i]) {
            dist += (maxB[i] - c[i]) * (maxB[i] - c[i]);
        }
    }
    return dist < r * r;
}

@compute
@workgroup_size(16, 16)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    if (globalIdx.x >= ${clusterX} || globalIdx.y >= ${clusterY} || globalIdx.z > ${clusterZ}) {
        return;
    }
    let clusterIdx = globalIdx.x + globalIdx.y * ${clusterX} + globalIdx.z * ${clusterX} * ${clusterY};
    let min_pt = to_ndc(vec3f(globalIdx));
    let max_pt = to_ndc(vec3f(globalIdx + 1));
    
    var minB = vec3(3.40282e+38);
    var maxB = vec3(-3.40282e+38);

    // FIXME: We can do better than looping over every frustum point
    for (var i : u32 = 0u; i < 8u; i++) {
        let selector = vec3<bool>(bool(i & 1), bool(i & 2), bool(i & 4));
        let ndc_point = select(min_pt, max_pt, selector);
        var transformed_point = cameraUniforms.invProj * vec4f(ndc_point, 1.0);
        transformed_point /= transformed_point.w;
        minB = min(minB, transformed_point.xyz);
        maxB = max(maxB, transformed_point.xyz);
    }

    var numLights = 0u;
    for (var i: u32 = 0u; i < lightSet.numLights; i++) {
        if (intersect(
            (cameraUniforms.view * vec4f(lightSet.lights[i].pos, 1)).xyz,
            ${lightRadius},
            minB,
            maxB)
        ) {
            clusters[clusterIdx].lights[numLights] = i;
            numLights++;
        }
        if (numLights >= ${maxClusterLights}) {
            break;
        }
    }

    clusters[clusterIdx].numLights = numLights;
}

