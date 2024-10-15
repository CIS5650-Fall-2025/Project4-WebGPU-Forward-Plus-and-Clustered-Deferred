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
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterLights: array<u32>;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput {
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Determine which cluster the fragment is in
    let screenWidth = cameraUniforms.screenWidth;
    let screenHeight = cameraUniforms.screenHeight;

    // pos is in world space
    var viewPos =  cameraUniforms.viewMat * vec4f(in.pos, 1.0);

    // fragPos is in clip space [-1, 1]
    //var viewPos =  cameraUniforms.invProjMat * in.fragPos;
    //viewPos = viewPos / viewPos.w;

    //let viewPos =  vec4f(in.pos, 1.0);
    let xCluster = u32(in.fragPos.x / screenWidth * f32(${clusterCountX}));
    let yCluster = u32(in.fragPos.y / screenHeight * f32(${clusterCountY}));

    //let test = viewPos1 - viewPos;
    // Compute depth in view space
    let depth = -viewPos.z;

    let zCluster = u32((depth - cameraUniforms.nearPlane) / (cameraUniforms.farPlane - cameraUniforms.nearPlane) * f32(${clusterCountZ}));

    // Clamp clusters
    let clusterIdX = clamp(xCluster, 0u, ${clusterCountX}u - 1u);
    let clusterIdY = clamp(yCluster, 0u, ${clusterCountY}u - 1u);
    let clusterIdZ = clamp(zCluster, 0u, ${clusterCountZ}u - 1u);

    // Compute cluster index
    let clusterIndex = clusterIdX + clusterIdY * ${clusterCountX}u + clusterIdZ * ${clusterCountX}u * ${clusterCountY}u;
    let clusterOffset = clusterIndex * (1u + ${maxLightsPerCluster}u);

    // Retrieve numLights
    let numLights = clusterLights[clusterOffset];

    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    for (var i = 0u; i < numLights; i = i + 1u) {
        let lightIdx = clusterLights[clusterOffset + 1u + i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1.0);
    //return vec4(vec3(depth,depth,depth),1.0);
    //return viewPos;
    //return vec4(test);
}