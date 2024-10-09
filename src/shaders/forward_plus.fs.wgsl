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
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    // Sample the diffuse texture
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // Determine which cluster contains the current fragment.
    let clusterIndex = getClusterIndex(in.fragCoord.xyz, in.pos);

    // Retrieve the number of lights that affect the current fragment from the cluster's data.
    let cluster = clusterSet.clusters[clusterIndex];
    let numLights = cluster.lightCount;

    // Initialize a variable to accumulate the total light contribution for the fragment.
    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    // For each light in the cluster:
    for (var i = 0u; i < numLights; i++) {
        // Access the light's properties using its index.
        let lightIndex = cluster.lightIndices[i];
        let light = lightSet.lights[lightIndex];

        // Calculate the contribution of the light based on its position, the fragment's position, and the surface normal.
        let lightContrib = calculateLightContrib(light, in.pos, in.nor);

        // Add the calculated contribution to the total light accumulation.
        totalLightContrib += lightContrib;
    }

    // Multiply the fragment's diffuse color by the accumulated light contribution.
    var finalColor = diffuseColor.rgb * totalLightContrib;

    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4(finalColor, 1.0);
}

fn getClusterIndex(fragCoord: vec3f, worldPos: vec3f) -> u32 {
    let screenSize = vec2f(cameraUniforms.screenWidth, cameraUniforms.screenHeight);
    let clusterSize = vec2f(screenSize.x / f32(clusterSet.numClustersX), screenSize.y / f32(clusterSet.numClustersY));
    
    let clusterX = u32(fragCoord.x / clusterSize.x);
    let clusterY = u32(fragCoord.y / clusterSize.y);
    
    let viewPos = (cameraUniforms.viewMat * vec4(worldPos, 1.0)).xyz;
    let depth = -viewPos.z;
    let zCluster = u32(log(depth / cameraUniforms.nearPlane) / log(cameraUniforms.farPlane / cameraUniforms.nearPlane) * f32(clusterSet.numClustersZ));
    
    return clusterX + 
           clusterY * clusterSet.numClustersX + 
           zCluster * clusterSet.numClustersX * clusterSet.numClustersY;
}