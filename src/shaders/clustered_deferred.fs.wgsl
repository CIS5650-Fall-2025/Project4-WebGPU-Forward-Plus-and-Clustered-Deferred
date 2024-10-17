// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.
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

    let screenSpacePos = (cameraUniforms.viewProjMat * vec4(in.pos, 1.0)).xyz;
    
    let clusterPosX = u32(floor(((screenSpacePos.xy / screenSpacePos.z).x * 0.5 + 0.5) * f32(clusterSet.clusterCount[0])));
    let clusterPosY = u32(floor(((screenSpacePos.xy / screenSpacePos.z).y * 0.5 + 0.5) * f32(clusterSet.clusterCount[1])));
    let clusterPosZ = u32(floor((-screenSpacePos.z - ${nearPlane}) / (${farPlane} - ${nearPlane}) * f32(clusterSet.clusterCount[2])));
    
    let clusterIdx = clusterPosX + 
                       clusterPosY * clusterSet.clusterCount[0] + 
                       clusterPosZ * clusterSet.clusterCount[0] * clusterSet.clusterCount[1];

    let cluster = clusterSet.clusters[clusterIdx];

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < cluster.noOfLights; lightIdx++) {
        let light = lightSet.lights[cluster.lightArray[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}