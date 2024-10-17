// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).

// bindGroup_scene is 0
// bindGroup_model is 1
// bindGroup_material is 2
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,   // Fragment position in view space
    @location(1) nor: vec3f,   // Fragment normal in view space
    @location(2) uv: vec2f     // UV coordinates for texture sampling
}

fn hash(value: vec2f) -> f32 {
    let dotResult = dot(value, vec2f(12.9898, 78.233)); 
    let sinResult = sin(dotResult) * 43758.5453;       
    return fract(sinResult);                         
}

fn random2(input: vec2f) -> vec3f {
    let x = hash(input) * 2.0 - 1.0; // Adjust to range [-1, 1]
    let y = hash(input + vec2f(1.0, 0.0)) * 2.0 - 1.0;
    let z = hash(input + vec2f(0.0, 1.0)) * 2.0 - 1.0;
    return vec3f(x, y, z);
}

fn random1(value: u32) -> vec3f {
    let x = fract(f32(value) * 0.0001);  
    let y = fract(f32(value) * 0.0002);  
    let z = fract(f32(value) * 0.0003);  
    return vec3f(x, y, z);               
}


@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5) {
        discard;
    }

    // Step 1: Determine which cluster the current fragment is in
    let screenPos = (cameraUniforms.viewProjMat * vec4(in.pos, 1.0)).xyz; 
    var fragCoordXY = (screenPos.xy / screenPos.z) * 0.5 + 0.5;            // Normalize to [0, 1] for XY
   // fragCoordXY.y = f32(1.0 - fragCoordXY.y); //ed screen space y is flipped
    let fragCoordZ = screenPos.z; // Use Z-depth in view space

    // The grid size is 16 X 16 X 16
    let gridSize = vec3f(cameraUniforms.clusterX, cameraUniforms.clusterY, cameraUniforms.clusterZ);
    let tileSize = vec2f(cameraUniforms.screenWidth / f32(gridSize.x), cameraUniforms.screenHeight / f32(gridSize.y));
    // let tileIdxX = u32(fragCoordXY.x * cameraUniforms.screenWidth / tileSize.x);
    // let tileIdxY = u32(fragCoordXY.y * cameraUniforms.screenHeight / tileSize.y);
    let tileIdxX = u32(fragCoordXY.x * 15.0);
    let tileIdxY = u32(fragCoordXY.y * 15.0);
    let depthSlice = u32((log2(abs(fragCoordZ) / cameraUniforms.zNear)* f32(gridSize.z)) / log2(cameraUniforms.zFar / cameraUniforms.zNear));

    let clusterIdx = tileIdxX + (tileIdxY * u32(gridSize.x)) + (depthSlice * u32(gridSize.x) * u32(gridSize.y));

    // Step 2: Retrieve the lights for this cluster
    let cluster = clusterSet.clusters[4000];// I did able to get all the cluster but the idex seems to be incorrect
    // let cluster = clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    // Step 3: Accumulate light contributions from lights affecting this fragment's cluster
    //  for (var lightIdx = 0u; lightIdx < 500u; lightIdx++) {
    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) {
        let lightIndex = cluster.lightIndices[lightIdx];
        let light = lightSet.lights[lightIndex];
        // Compute the light contribution for this fragment using a basic Lambertian model
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    // Step 4: Multiply the diffuse color by the accumulated light contribution
    var finalColor = diffuseColor.rgb * totalLightContrib;

   //Test buffer
    let camWidth = cameraUniforms.screenWidth / 2560.0; // correct
    let camHei = cameraUniforms.screenHeight / 1398.0; // correct
    let camClus = cameraUniforms.clusterZ / 16.0; // correct
    let camZnear = cameraUniforms.zNear / 0.1; // correct

    //Test Cluster buffer
    let clusMinPos = cluster.minPos.xyz;  // correct
    let clusMaxPos = cluster.maxPos.xyz;  // correct
    let clusLightNum = f32(cluster.numLights) / 500.0;  // correct

    let red3 = f32(cluster.numLights)/10.3; // wrong
    let green3 = f32(clusterIdx); // wrong
    let red4 = cluster.minPos.x;
    let test = diffuseColor.rgb + vec3f(red4, 0.0, 0.0);
    let test2 = random2(vec2f(f32(tileIdxX), f32(tileIdxY)));
    let test1 =  random1(clusterIdx);
    let depthSliceVis = f32(depthSlice) / f32(gridSize.z);  // Normalize depthSlice to [0, 1]
    // return vec4(depthSliceVis,depthSliceVis,depthSliceVis, 1.0);
    // return vec4(clusLightNum,0.0,0.0, 1.0);
    // return vec4(clusMinPos, 1.0);
    return vec4(finalColor, 1);
}

//naive.fs
// @fragment
// fn main(in: FragmentInput) -> @location(0) vec4f {
//         let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
//     if (diffuseColor.a < 0.5f) {
//         discard;
//     }

//     var totalLightContrib = vec3f(0, 0, 0);
//     for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
//         let light = lightSet.lights[lightIdx];
//         totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
//     }

//     var finalColor = diffuseColor.rgb * totalLightContrib;
//     return vec4(finalColor, 1);
// }