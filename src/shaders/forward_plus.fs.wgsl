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
    @location(0) posWorld: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

fn hash_to_float(x: u32) -> f32 {
    var hash = x;
    hash = (hash ^ (hash >> 16)) * 0x85ebca6b;
    hash = (hash ^ (hash >> 13)) * 0xc2b2ae35;
    hash = hash ^ (hash >> 16);

    // Convert to float in the range [0, 1]
    return f32(hash & 0x7FFFFFFF) / 2147483647.0;
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    // figure out in which cluster we are in
    let clipPlaneRatio = cameraUniforms.clipPlanes[1] / cameraUniforms.clipPlanes[0];
    
    let posClip = cameraUniforms.viewProjMat * vec4f(in.posWorld, 1);
    var posNDC = posClip.xyz / posClip.w;
    //var posNDC = posClip.xyz ;
    //posNDC.x = 0.5 * (posNDC.x + 1);
    //posNDC.y = 0.5 * (posNDC.y + 1);
    posNDC.z = clamp(posNDC.z, 0, 1);
    
    
    //let posNDC = dingens.xyz;

    let thingy = cameraUniforms.viewMat * vec4f(in.posWorld, 1);
    let slice = u32(log(-thingy.z) * f32(clusterSet.numClusters.z) / log(clipPlaneRatio) - f32(clusterSet.numClusters.z) * log(cameraUniforms.clipPlanes[0]) / log(clipPlaneRatio));

    let clusterPos = vec3u(
        u32(0.5 * (posNDC.x + 1) * f32(clusterSet.numClusters.x)),
        u32(0.5 * (posNDC.y + 1) * f32(clusterSet.numClusters.y)),
        //u32(f32(clusterSet.numClusters.z) * log(posNDC.z * (clipPlaneRatio - 1)) / log(clipPlaneRatio))
        slice
    );

    let clusterIdx = calculateClusterIdx(clusterPos, clusterSet.numClusters);

    let cluster = &clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < (*cluster).numLights; i++) {
        let lightIdx = (*cluster).lightIndices[i];
        let light = lightSet.lights[i];
        totalLightContrib += calculateLightContrib(light, in.posWorld, in.nor);
    }

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let finalColor = diffuseColor.rgb * totalLightContrib;
    //return vec4f(0.5 * (posNDC + 1), 1);
    let r = hash_to_float(clusterIdx + 1);
    let g = hash_to_float(clusterIdx + 2);
    let b = hash_to_float(clusterIdx + 3);
    let a = f32((*cluster).numLights) / 100;
    // return vec4f(f32(clusterIdx) / 1000, f32(clusterIdx) / 1000, f32(clusterIdx) / 1000, 1);
    // return vec4f(posNDC.x , posNDC.y, 1 , 1);
    // return vec4f(r, g, b, 1);
    // return vec4f(posNDC.x, posNDC.x, posNDC.x, 1);
    return vec4f(finalColor, 1);
}