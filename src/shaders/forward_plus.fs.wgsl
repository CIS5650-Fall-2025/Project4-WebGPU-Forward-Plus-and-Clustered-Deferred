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
fn main(in: FragmentInput, @builtin(position) fragPos: vec4<f32>) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    let strideX = f32(cameraUniforms.xdim) / f32(clusterSet.tileNumX);
    let strideY = f32(cameraUniforms.ydim) / f32(clusterSet.tileNumY);
    let tileX = u32(fragPos.x / strideX);
    let tileY = u32(fragPos.y / strideY);
    let zView = fragPos.z * (cameraUniforms.fclip - cameraUniforms.nclip) + cameraUniforms.nclip;
    let logZ = log(zView / cameraUniforms.nclip) / log(cameraUniforms.fclip / cameraUniforms.nclip);
    let tileZ = u32(logZ * f32(clusterSet.tileNumZ));

    let clusterIdx = tileX + clusterSet.tileNumX * tileY + clusterSet.tileNumX * clusterSet.tileNumY * tileZ;
    let cluster = clusterSet.clusters[clusterIdx];

    var totalLightContrib = vec3f(0, 0, 0);
    for (var idx = 0u; idx < cluster.numLights; idx++) {
        let lightIdx = cluster.lightInx[idx];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
    // return vec4(f32(tileX) / f32(clusterSet.numTileX), f32(tileY) / f32(clusterSet.numTileY), f32(tileZ) / f32(${depthSlice}), 1.0);
    // return vec4(f32(cluster.numLights) / 16.0, 0, 0, 1);
    // if (tileZ == 31) {
    //     return vec4(1, 0, 0, 1);
    // } else {
    //     return vec4(0, 0, 0, 1);
    // }
    // return vec4(logZ, 0, 0, 1);
    // return vec4(f32(clusterIdx) / f32(clusterSet.tileNum), f32(clusterIdx) / f32(clusterSet.tileNum), f32(clusterIdx) / f32(clusterSet.tileNum), 1.0);
}
