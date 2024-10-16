// TODO-2: implement the light clustering compute shader
// bindGroup_scene is 0
// bindGroup_model is 1
// bindGroup_material is 2
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read_write> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

fn screenToView(screenCoord: vec2f) -> vec3f {
    let ndc = vec4f((screenCoord.x / cameraUniforms.screenWidth) * 2.0 - 1.0, (screenCoord.y / cameraUniforms.screenHeight) * 2.0 - 1.0, -1.0, 1.0);
    // let viewPos = cameraUniforms.invViewProjMat * ndc;
    var viewPos = cameraUniforms.invViewProjMat * ndc;
    viewPos.y = -viewPos.y;
    return viewPos.xyz / viewPos.w;
}

fn lineIntersectionWithZPlane(startPoint: vec3f, endPoint: vec3f, zPlane: f32) -> vec3f {
    let direction = endPoint - startPoint;
    let normal = vec3f(0.0, 0.0, -1.0);
    let d = dot(normal, startPoint);
    let t = (zPlane - d) / dot(normal, direction);
    return startPoint + t * direction;
}

fn sphereIntersectsAABB(center: vec3f, radius: f32, aabbMin: vec3f, aabbMax: vec3f) -> bool {
    // closest point on the AABB to the sphere center
    let closestPoint = clamp(center, aabbMin, aabbMax);
    // distance between the sphere center and this closest point
    let distance = length(center - closestPoint);
    return distance <= radius;
}

@compute
//CUDA block size. Specify the size in the shader.
//maxComputeInvocationsPerWorkgroup = 256
@workgroup_size(16, 16, 1)
//global_invocation_id is equivalent to blockIdx * blockdim + threadIdx
fn main(@builtin(global_invocation_id) globalIdx: vec3u){
// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// Basic setup
//The grid size is : x = Math.ceil(canvas.width/64);  y = Math.ceil(canvas.height/64);  z = 64;
let gridSize = vec3f(cameraUniforms.clusterX, cameraUniforms.clusterY, cameraUniforms.clusterZ);
let tileIdx = globalIdx.x + (globalIdx.y * u32(gridSize.x)) + (globalIdx.z * u32(gridSize.x) * u32(gridSize.y));

let zNear = cameraUniforms.zNear;
let zFar = cameraUniforms.zFar;
let screenWidth = cameraUniforms.screenWidth;
let screenHeight = cameraUniforms.screenHeight;
let viewProjMat = cameraUniforms.viewProjMat;

// Calculate the cluster's screen-space bounds in 2D (XY).
// let tileSize = vec2f(screenWidth / f32(gridSize.x), screenHeight / f32(gridSize.y));
let tileSize = vec2f(64.0, 64.0);
// Get current thread index 
let tileIdxX = globalIdx.x;
let tileIdxY = globalIdx.y;
let tileIdxZ = globalIdx.z;

// Tile in screen space
let minTile_Screenspace = vec2f(f32(tileIdxX) * tileSize.x, f32(tileIdxY) * tileSize.y);
let maxTile_Screenspace = vec2f(f32(tileIdxX + 1) * tileSize.x, f32(tileIdxY + 1) * tileSize.y);

// Convert tile in the screen space to the space sitting on the near plane
var minTile_Viewspace = screenToView(minTile_Screenspace);
var maxTile_Viewspace = screenToView(maxTile_Screenspace);

// Calculate the depth bounds for this cluster in Z (near and far planes
var planeNear = zNear * pow(zFar/zNear, f32(tileIdxZ)/ f32(gridSize.z));
var planeFar = zNear * pow(zFar/zNear, f32(tileIdxZ + 1)/ f32(gridSize.z));

// Use vec3(0,0,0) or camera position as the starting point
var minPointNear = lineIntersectionWithZPlane(vec3f(0.0,0.0,0.0), minTile_Viewspace, planeNear);
var minPointFar = lineIntersectionWithZPlane(vec3f(0.0,0.0,0.0), minTile_Viewspace, planeFar);
var maxPointNear = lineIntersectionWithZPlane(vec3f(0.0,0.0,0.0), maxTile_Viewspace, planeNear);
var maxPointFar = lineIntersectionWithZPlane(vec3f(0.0,0.0,0.0), maxTile_Viewspace, planeFar);

// var minPointNear = lineIntersectionWithZPlane(vec3f(-7.0, 2.0, 0.0), minTile_Viewspace, planeNear);
// var minPointFar = lineIntersectionWithZPlane(vec3f(-7.0, 2.0, 0.0), minTile_Viewspace, planeFar);
// var maxPointNear = lineIntersectionWithZPlane(vec3f(-7.0, 2.0, 0.0), maxTile_Viewspace, planeNear);
// var maxPointFar = lineIntersectionWithZPlane(vec3f(-7.0, 2.0, 0.0), maxTile_Viewspace, planeFar);

var minPos = vec4f(min(minPointNear, minPointFar), 0.0);
var maxPos = vec4f(max(maxPointNear, maxPointFar), 0.0);
clusterSet.clusters[tileIdx].minPos = minPos;
clusterSet.clusters[tileIdx].maxPos = maxPos;

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

var lightNum: u32 = 0u;
for (var i = 0u; i < lightSet.numLights; i++) {
    var light = lightSet.lights[i];
    var lightPos = light.pos;
    var lightColor = light.color;
    // hardcoded light radius for now
    let lightRadius = 2.0; // in shader.ts

    // Check if the light intersects with the cluster’s bounding box (AABB).
    var lightIntersectsCluster = sphereIntersectsAABB(lightPos, lightRadius, minPos.xyz, maxPos.xyz);
    if(lightNum < 100u && lightIntersectsCluster) {
        // Add the light to the cluster's light list.
        clusterSet.clusters[tileIdx].lightIndices[lightNum] = i;
        // clusterSet.clusters[tileIdx].numLights = lightNum + 1u;
        lightNum = lightNum + 1u;

    }   
}
clusterSet.clusters[tileIdx].numLights = lightNum;

//Test buffer write and did work then is sth wrong with index
// for(var i = 0u; i <= 500u; i++) {
//     clusterSet.clusters[i].lightIndices[i % 100] = i % 100;
//     clusterSet.clusters[i].minPos = vec4f(1.0, 0.0, 0.0, 1.0); // Set a uniform value to all clusters for testing
//     clusterSet.clusters[i].maxPos = vec4f(0.0, 1.0, 0.0, 2.0); // Example value
// }
// clusterSet.clusters[tileIdx].numLights = 500u;
}