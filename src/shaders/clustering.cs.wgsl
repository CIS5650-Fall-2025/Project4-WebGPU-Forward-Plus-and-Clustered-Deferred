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

@compute
@workgroup_size(8, 8, 4)
fn main(@builtin(global_invocation_id) workgroupID: vec3<u32>) {
    // tile index and cluster index
    let idx: u32 = workgroupID.x;
    let idy: u32 = workgroupID.y;
    let idz: u32 = workgroupID.z;

    if (idx >= ${tileNumberX}|| idy >= ${tileNumberY} || idz >= ${tileNumberZ}) {
        return;
    }

    let clusterIdx: u32 = idx + ${tileNumberX} * idy + ${tileNumberX} * ${tileNumberY} * idz;
    
    // ndc range
    let xMin: f32 = (f32(idx) / f32(${tileNumberX})) * 2f - 1f;
    let xMax: f32 = (f32(idx + 1) / f32(${tileNumberX})) * 2f - 1f;
    let yMin: f32 = 1f - (f32(idy) / f32(${tileNumberY})) * 2f;
    let yMax: f32 = 1f - (f32(idy + 1) / f32(${tileNumberY})) * 2f;
    // let zMin: f32 = (0.1 * pow(10000, f32(idz) / f32(clusterSet.numTileZ)) - 0.1) / 999.9;
    // let zMax: f32 = (0.1 * pow(10000, f32(idz + 1) / f32(clusterSet.numTileZ)) - 0.1) / 999.9;
    // let zMin: f32 = f32(idz) / f32(${tileNumberZ});
    // let zMax: f32 = f32(idz + 1) / f32(${tileNumberZ});
    let zMinView: f32 = clusterSet.nclip * pow((clusterSet.fclip / clusterSet.nclip), f32(idz) / f32(${tileNumberZ}));
    let zMaxView: f32 = clusterSet.nclip * pow((clusterSet.fclip / clusterSet.nclip), f32(idz + 1) / f32(${tileNumberZ}));
    let zMin: f32 = (zMinView - clusterSet.nclip) / (clusterSet.fclip - clusterSet.nclip);
    let zMax: f32 = (zMaxView - clusterSet.nclip) / (clusterSet.fclip - clusterSet.nclip);

    // perspective camera range
    let cor1: vec4f = cameraUniforms.inverseProj * vec4(xMin, yMin, zMin, 1.0);
    let cor2: vec4f = cameraUniforms.inverseProj * vec4(xMin, yMax, zMin, 1.0);
    let cor3: vec4f = cameraUniforms.inverseProj * vec4(xMin, yMin, zMax, 1.0);
    let cor4: vec4f = cameraUniforms.inverseProj * vec4(xMin, yMax, zMax, 1.0);
    let cor5: vec4f = cameraUniforms.inverseProj * vec4(xMax, yMin, zMin, 1.0);
    let cor6: vec4f = cameraUniforms.inverseProj * vec4(xMax, yMax, zMin, 1.0);
    let cor7: vec4f = cameraUniforms.inverseProj * vec4(xMax, yMin, zMax, 1.0);
    let cor8: vec4f = cameraUniforms.inverseProj * vec4(xMax, yMax, zMax, 1.0);

    // camera range
    let cor1_v: vec3f = vec3(cor1.x / cor1.w, cor1.y / cor1.w, cor1.z / cor1.w);
    let cor2_v: vec3f = vec3(cor2.x / cor2.w, cor2.y / cor2.w, cor2.z / cor2.w);
    let cor3_v: vec3f = vec3(cor3.x / cor3.w, cor3.y / cor3.w, cor3.z / cor3.w);
    let cor4_v: vec3f = vec3(cor4.x / cor4.w, cor4.y / cor4.w, cor4.z / cor4.w);
    let cor5_v: vec3f = vec3(cor5.x / cor5.w, cor5.y / cor5.w, cor5.z / cor5.w);
    let cor6_v: vec3f = vec3(cor6.x / cor6.w, cor6.y / cor6.w, cor6.z / cor6.w);
    let cor7_v: vec3f = vec3(cor7.x / cor7.w, cor7.y / cor7.w, cor7.z / cor7.w);
    let cor8_v: vec3f = vec3(cor8.x / cor8.w, cor8.y / cor8.w, cor8.z / cor8.w);

    // bbox
    let bboxMinx: f32 = min(min(min(cor1_v.x, cor2_v.x), min(cor3_v.x, cor4_v.x)), min(min(cor5_v.x, cor6_v.x), min(cor7_v.x, cor8_v.x)));
    let bboxMiny: f32 = min(min(min(cor1_v.y, cor2_v.y), min(cor3_v.y, cor4_v.y)), min(min(cor5_v.y, cor6_v.y), min(cor7_v.y, cor8_v.y)));
    let bboxMinz: f32 = min(min(min(cor1_v.z, cor2_v.z), min(cor3_v.z, cor4_v.z)), min(min(cor5_v.z, cor6_v.z), min(cor7_v.z, cor8_v.z)));
    let bboxMaxx: f32 = max(max(max(cor1_v.x, cor2_v.x), max(cor3_v.x, cor4_v.x)), max(max(cor5_v.x, cor6_v.x), max(cor7_v.x, cor8_v.x)));
    let bboxMaxy: f32 = max(max(max(cor1_v.y, cor2_v.y), max(cor3_v.y, cor4_v.y)), max(max(cor5_v.y, cor6_v.y), max(cor7_v.y, cor8_v.y)));
    let bboxMaxz: f32 = max(max(max(cor1_v.z, cor2_v.z), max(cor3_v.z, cor4_v.z)), max(max(cor5_v.z, cor6_v.z), max(cor7_v.z, cor8_v.z)));

    // set bbox values
    clusterSet.clusters[clusterIdx].minPos = vec3f(bboxMinx, bboxMiny, bboxMinz);
    clusterSet.clusters[clusterIdx].maxPos = vec3f(bboxMaxx, bboxMaxy, bboxMaxz);

    // check lights
    var lightCount: u32 = 0;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light: Light = lightSet.lights[lightIdx];
        // light pos in camera
        let lightPos_v: vec4f = cameraUniforms.viewMat * vec4(light.pos.x, light.pos.y, light.pos.z, 1.0);

        // find closest point on bbox
        // let closest_x: f32 = max(bboxMinx, min(bboxMaxx, lightPos_v.x));
        // let closest_y: f32 = max(bboxMiny, min(bboxMaxy, lightPos_v.y));
        // let closest_z: f32 = max(bboxMinz, min(bboxMaxz, lightPos_v.z));
        // let dis_squ: f32 = pow((closest_x - lightPos_v.x), 2.0) + pow((closest_y - lightPos_v.y), 2.0) + pow((closest_z - lightPos_v.z), 2.0);

        let closestPoint = clamp(lightPos_v.xyz, vec3(bboxMinx, bboxMiny, bboxMinz), vec3(bboxMaxx, bboxMaxy, bboxMaxz));
        let distance = length(lightPos_v.xyz - closestPoint);

        // check intersect
        if (distance <= (${lightRadius})) {
            // add to cluster light index array
            clusterSet.clusters[clusterIdx].lightInx[lightCount] = lightIdx;
            lightCount++;
            if (lightCount == ${maxLightsNumPerCluster}) {
                // reach maximum lights number
                break;
            }
        }
    }

    // set lights number
    clusterSet.clusters[clusterIdx].numLights = lightCount;
}