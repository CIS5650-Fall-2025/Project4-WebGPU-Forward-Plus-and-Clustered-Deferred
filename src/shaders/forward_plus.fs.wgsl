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
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusters: array<ClusterSet>;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }
    let clusterIndex = getClusterIndex(in.pos, cameraUniforms);

    let cluster = clusters[clusterIndex];
    let lightCount = cluster.lightCount;
    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    for (var i = 0u; i < lightCount; i++) {
        let lightIndex = cluster.lightIndices[i];
        let light = lightSet.lights[lightIndex];

        let lightContrib = calculateLightContrib(light, in.pos, in.nor);
        totalLightContrib += lightContrib;
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1.0);
}

fn getClusterIndex(posWorld: vec3f, camera: CameraUniforms) -> u32 {
    let pos4_ndc = camera.viewProjMat * vec4<f32>(posWorld, 1.0);
    let pos_ndc = pos4_ndc.xyz / pos4_ndc.w;

    let xIndex = u32((pos_ndc.x * 0.5 + 0.5) * ${clusteringCountX});
    let yIndex = u32((pos_ndc.y * 0.5 + 0.5) * ${clusteringCountY});

    let Z_view = (camera.viewMat * vec4<f32>(posWorld, 1.0)).z;
    let zIndex = u32(log(Z_view / -f32(${nearClip})) / log(f32(${farClip}) / f32(${nearClip})) * f32(${clusteringCountZ}));
    var clusterIndex = xIndex + yIndex * ${clusteringCountX} + zIndex * ${clusteringCountX} * ${clusteringCountY};
    
    return clusterIndex;
}