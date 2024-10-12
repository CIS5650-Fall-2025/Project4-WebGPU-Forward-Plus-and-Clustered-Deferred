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

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraData: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusters: array<Cluster>;
@group(${bindGroup_scene}) @binding(3) var<uniform> clusterGrid: ClusterGridMetadata; 

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput {
    @location(0) pos: vec3f, 
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
    @builtin(position) fragCoord: vec4f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let clusterIndex = calculateClusterIndex(in.fragCoord, in.pos);
    let currentCluster = clusters[0];

    var totalLightContrib = vec3f(0, 0, 0);
    // for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
    //     let light = lightSet.lights[lightIdx];
    //     totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    // }

    for (var i = 0u; i < currentCluster.numLights; i++) {
        let lightIdx = currentCluster.lightIndices[i];

        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}

fn calculateClusterIndex(fragCoord: vec4f, fragPos: vec3f) -> u32 {
    let clusterX = u32(fragCoord.x / f32(clusterGrid.canvasWidth) * f32(clusterGrid.clusterGridSizeX));
    let clusterY = u32(fragCoord.y / f32(clusterGrid.canvasHeight) * f32(clusterGrid.clusterGridSizeY));

    let zDepth = length(fragPos - cameraData.cameraPos);
    let logZRatio = log2(cameraData.zFar / cameraData.zNear);
    let clusterZ = u32(log2(zDepth / cameraData.zNear) / logZRatio * f32(clusterGrid.clusterGridSizeZ));

    return clusterX + clusterY * clusterGrid.clusterGridSizeX + clusterZ * clusterGrid.clusterGridSizeX * clusterGrid.clusterGridSizeY;
}
