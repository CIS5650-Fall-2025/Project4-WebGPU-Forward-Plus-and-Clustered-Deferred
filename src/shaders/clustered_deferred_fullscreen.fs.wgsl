@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(1) @binding(0) var posTexture: texture_storage_2d<rgba16float, read>;
@group(1) @binding(1) var albTexture: texture_2d<f32>;
@group(1) @binding(2) var norTexture: texture_storage_2d<rgba16float, read>;


@fragment
fn main(@builtin(position) screenPos : vec4f) -> @location(0) vec4f {
    let position = textureLoad(posTexture, vec2i(floor(screenPos.xy))).xyz;
    let albedo   = textureLoad(albTexture, vec2i(floor(screenPos.xy)), 0).xyz;
    let normal   = textureLoad(norTexture, vec2i(floor(screenPos.xy))).xyz;

    let clusterPos = calculateClusterPos(position, &cameraUniforms, clusterSet.numClusters);

    let clusterIdx = calculateClusterIdx(clusterPos, clusterSet.numClusters);

    let cluster = &clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < (*cluster).numLights; i++) {
        let lightIdx = (*cluster).lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, position, normal);
    }

    let finalColor = albedo * totalLightContrib;
    return vec4f(finalColor, 1);
}