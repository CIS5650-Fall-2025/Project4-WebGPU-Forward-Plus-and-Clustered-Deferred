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

    // Determine which cluster contains the current fragment.
    let viewPos = (cameraUniforms.viewProjMat * vec4(in.pos, 1.0)).xyz;
    let ndc = viewPos.xy / viewPos.z;
    
    let clusterX = u32(floor((ndc.x * 0.5 + 0.5) * f32(clusterSet.numClustersX)));
    let clusterY = u32(floor((ndc.y * 0.5 + 0.5) * f32(clusterSet.numClustersY)));
    
    let viewZ = -viewPos.z;
    let zNear = cameraUniforms.nearPlane;
    let zFar = cameraUniforms.farPlane;
    let clusterZ = u32(floor(log(viewZ / zNear) / log(zFar / zNear) * f32(clusterSet.numClustersZ)));
    
    let clusterIndex = clusterX + 
                       clusterY * clusterSet.numClustersX + 
                       clusterZ * clusterSet.numClustersX * clusterSet.numClustersY;


    // Retrieve the number of lights that affect the current fragment from the cluster's data.
    let cluster = clusterSet.clusters[clusterIndex];
    let numLightsInCluster = cluster.lightCount;

    var totalLightContrib = vec3f(0.0, 0.0, 0.0);
    // For each light in the cluster:
    for (var i = 0u; i < numLightsInCluster; i++) {
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