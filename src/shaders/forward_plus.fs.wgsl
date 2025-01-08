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

struct FragmentInput {
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    // Sample texture color
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let clipPlaneRatio = cameraUniforms.clipPlanes[1] / cameraUniforms.clipPlanes[0];

    // Get position in view space
    let posView = cameraUniforms.viewMat * vec4f(in.pos, 1);
    
    // Get x- and y-coordinate in NDC space
    let posClip = cameraUniforms.viewProjMat  * vec4f(in.pos, 1);
    let xyNDC = posClip.xy / posClip.w;

    // Get cluster position from calculated coordinates
    let clusterPos = vec3u(
        u32(0.5 * (xyNDC.x + 1) * f32(clusterSet.numClusters.x)),
        u32(0.5 * (xyNDC.y + 1) * f32(clusterSet.numClusters.y)),
        // Get z-slice from z-coordinate in view space (negative z!)
        u32(f32(clusterSet.numClusters.z) * log(- posView.z / cameraUniforms.clipPlanes[0]) / log(clipPlaneRatio))
    );

    let clusterIdx = calculateClusterIdx(clusterPos, clusterSet.numClusters);

    let cluster = &clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < (*cluster).numLights; i++) {
        let lightIdx = (*cluster).lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4f(finalColor, 1);
}