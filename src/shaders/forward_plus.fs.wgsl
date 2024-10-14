// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

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
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);

    // Determine which cluster contains the current fragment
    var zTile = ((log(abs(in.pos.z) / cameraUniforms.zNear)) * f32(cameraUniforms.tileCountZ)) / log(cameraUniforms.zFar / cameraUniforms.zNear);
    var tileXYZ = vec3u(
        min(cameraUniforms.tileCountX - 1u, u32(in.pos.x / f32(cameraUniforms.tileSize))),
        min(cameraUniforms.tileCountY - 1u, u32(in.pos.y / f32(cameraUniforms.tileSize))),
        min(cameraUniforms.tileCountZ - 1u, u32(zTile))
    );
    var tileIdx = tileXYZ.x + tileXYZ.y * cameraUniforms.tileCountX + tileXYZ.z * cameraUniforms.tileCountX * cameraUniforms.tileCountY;

    // Retrieve the number of lights that affect the current fragment from the cluster’s data
    var cluster = clusterSet.clusters[tileIdx];
    var numLights = cluster.lightCount; 

    // For each light in the cluster
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        let light = lightSet.lights[cluster.lightIndices[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = vec3f(0.0, 0.0, 0.0);

    //finalColor = diffuseColor.rgb * totalLightContrib;
    //finalColor = f32(numLights) * diffuseColor.rgb;

    if(numLights == 0u) {
        finalColor = diffuseColor.rgb;
    }

    // if(cluster.maxPoint.x == 0.0 && cluster.maxPoint.y == 0.0 && cluster.maxPoint.z == 0.0) {
    //     finalColor = diffuseColor.rgb;
    // }

    //finalColor = vec3f(f32(tileXYZ.x), f32(tileXYZ.y), f32(tileXYZ.z)) / vec3f(f32(cameraUniforms.tileCountX), f32(cameraUniforms.tileCountY), f32(cameraUniforms.tileCountZ));

    return vec4f(finalColor, 1);
}