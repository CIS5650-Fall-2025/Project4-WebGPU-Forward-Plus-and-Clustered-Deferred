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

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read_write> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read_write> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,   // Fragment position in view space
    @location(1) nor: vec3f,   // Fragment normal in view space
    @location(2) uv: vec2f     // UV coordinates for texture sampling
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5) {
        discard;
    }

    // Step 1: Determine which cluster the current fragment is in
    let screenPos = (cameraUniforms.viewProjMat * vec4(in.pos, 1.0)).xyz; 
    let fragCoordXY = (screenPos.xy / screenPos.z) * 0.5 + 0.5;            // Normalize to [0, 1] for XY
    let fragCoordZ = in.pos.z;                                              // Use Z-depth in view space

    // Compute which 2D tile and Z slice the fragment belongs to
    let tileSize = vec2(cameraUniforms.screenWidth / f32(cameraUniforms.gridSize.x), cameraUniforms.screenHeight / f32(cameraUniforms.gridSize.y));
    let tileIdxX = u32(fragCoordXY.x * cameraUniforms.screenWidth / tileSize.x);
    let tileIdxY = u32(fragCoordXY.y * cameraUniforms.screenHeight / tileSize.y);
    let depthSlice = u32(log2(fragCoordZ / cameraUniforms.zNear) / log2(cameraUniforms.zFar / cameraUniforms.zNear) * f32(cameraUniforms.gridSize.z));

    let clusterIdx = tileIdxX + tileIdxY * cameraUniforms.gridSize.x + depthSlice * cameraUniforms.gridSize.x * cameraUniforms.gridSize.y;

    // Step 2: Retrieve the lights for this cluster
    let cluster = clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    // Step 3: Accumulate light contributions from lights affecting this fragment's cluster
    for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) {
        let lightIndex = cluster.lightIndices[lightIdx];
        let light = lightSet.lights[lightIndex];

        // Compute the light contribution for this fragment using a basic Lambertian model
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    // Step 4: Multiply the diffuse color by the accumulated light contribution
    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1.0);

   // var totalLightContrib = vec3f(0, 0, 0);
    // for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
    //     let light = lightSet.lights[lightIdx];
    //     totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    // }

    // var finalColor = diffuseColor.rgb * totalLightContrib;
    // return vec4(finalColor, 1);
    // return vec4(1.0,1.0,0.0, 1.0);
}


// @fragment
// fn main(in: FragmentInput) -> @location(0) vec4f
// {
//     // Sample the diffuse texture
//     let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
//     if (diffuseColor.a < 0.5) {
//         discard;
//     }

//     // Step 1: Determine which cluster the current fragment is in
//     let screenPos = (cameraUniforms.viewProjMat * vec4(in.pos, 1.0)).xyz;  // Project the fragment position to screen space
//     let fragCoordXY = (screenPos.xy / screenPos.z) * 0.5 + 0.5;            // Normalize to [0, 1] for XY
//     let fragCoordZ = in.pos.z;                                             // Use Z-depth in view space

//     // Compute which 2D tile and Z slice the fragment belongs to
//     let tileSize = vec2(cameraUniforms.screenWidth / 32.0, cameraUniforms.screenHeight / 32.0);
//     let tileIdxX = u32(fragCoordXY.x * cameraUniforms.screenWidth / tileSize.x);
//     let tileIdxY = u32(fragCoordXY.y * cameraUniforms.screenHeight / tileSize.y);
//     let depthSlice = u32(log2(fragCoordZ / cameraUniforms.zNear) / log2(cameraUniforms.zFar / cameraUniforms.zNear) * 32.0);

//     let clusterIdx = tileIdxX + tileIdxY * 32u + depthSlice * 32u * 32u;

//     // Step 2: Retrieve the lights for this cluster
//     let cluster = clusterSet.clusters[clusterIdx];
//     var totalLightContrib = vec3f(0.0, 0.0, 0.0);

//     // Step 3: Accumulate light contributions from lights affecting this fragment's cluster
//     for (var lightIdx = 0u; lightIdx < cluster.numLights; lightIdx++) {
//         let lightIndex = cluster.lightIndices[lightIdx];
//         let light = lightSet.lights[lightIndex];

//         // Compute the light contribution for this fragment (e.g., using Lambertian shading or Phong)
//         totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
//     }

//     // Step 4: Multiply the diffuse color by the accumulated light contribution
//     var finalColor = diffuseColor.rgb * totalLightContrib;

//     return vec4(0.0,1.0,0.0, 1.0);
// }

