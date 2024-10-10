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
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Determine which cluster contains the current fragment
    let posViewSpace = cameraUniforms.view * vec4f(in.pos, 1.0);
    let posNDCSpace = ((posViewSpace.xy / posViewSpace.z) + vec2f(1.0, 1.0)) * 0.5;
    let clusterIndexX = u32(posNDCSpace.x * clusterSet.numClusters.x);
    let clusterIndexY = u32(posNDCSpace.y * clusterSet.numClusters.y);
    let clusterIndexZ = u32((posViewSpace.z - cameraUniforms.nearFar.x) / (cameraUniforms.nearFar.y - cameraUniforms.nearFar.x) * clusterSet.numClusters.z);

    let clusterIndex = clusterIndexX + 
                    clusterIndexY * clusterSet.numClusters.x + 
                    clusterIndexZ * clusterSet.numClusters.y * clusterSet.numClusters.x;

    let numLights = clusterSet.clusters[clusterIndex].numLights;

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        let light = lightSet.lights[clusterSet.clusters[clusterIndex].lights[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
