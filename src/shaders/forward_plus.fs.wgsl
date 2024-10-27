@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUnifs: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

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



struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    // Position Reversal Code
    // Need to get x idx, y idx and z idx
    // x and y idx I can find by converting this pos to screen space and then flooring
    // z I can find by converting to view space and then inverting the exponential depth slicing formula I used in clustering

    // -x and y
    let clipSpaceCoord = (cameraUnifs.viewProjMat * vec4f(in.pos, 1.0));
    let screenSpaceCoord = ((clipSpaceCoord / clipSpaceCoord.w) + 1.0) * 0.5;
    let x_idx : u32 = u32(screenSpaceCoord.x * f32(clusterSet.clustersDim.x));
    let y_idx : u32 = u32(screenSpaceCoord.y * f32(clusterSet.clustersDim.y));

    let clusterIdx = x_idx + y_idx * clusterSet.clustersDim.x;
    
    // Rendering Code
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);

    // Light Accumulation Loop
    let cluster = clusterSet.clusters[1];
    var bruh = vec3f(0,0,0);

    if (clusterIdx != 1) {
        // return vec4(1,1,1,1);
        bruh = vec3f(0.1,0.1,0.1);
    }

    let numLights = cluster.numLights;
    
    for (var lightNum = 0u; lightNum < numLights; lightNum++) {
        let lightIdx = cluster.lights[lightNum];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
        // bruh = vec3f(0,0,1);
    }
    // bruh = vec3f(0,0,1);
    // for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
    //     let light = lightSet.lights[lightIdx];
    //     totalLightContrib += calculateLightContrib(light, in.pos, normalize(in.nor));
    // }
    // Light Accumulation Loop


    var finalColor = diffuseColor.rgb * totalLightContrib;
    // var finalColor = vec3f(1,1,1);
    // let clusterLights = clusterSet[].numLights;
    // clusterSet.clusters[0].numLights = 420;
    // let i = clusterSet.clusters[0].numLights;
    // i = clipSpaceCoord.z;
    // let i = clusterSet.numClusters;
    // let i = clusterSet.clustersDim.z;
    // let i = z_idx;

    let i = numLights;
    // if (i > 0) {
    //     return vec4(1,0,1,1);
    // } else {
    //     return vec4(0,1,0,1);
    // }
    // let testUVCol : vec3f = vec3f(f32(x_idx) / f32(clusterSet.clustersDim.x), 0, f32(y_idx) / f32(clusterSet.clustersDim.y));
    // return vec4(testUVCol, 1);

    // let testClusterIdx : vec3f = vec3f(f32(clusterIdx) / f32(clusterSet.numClusters), 0, 0);
    // return vec4(testClusterIdx, 1);

    return vec4(finalColor + bruh, 1);
}