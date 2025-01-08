@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(1) @binding(0) var packedTexture: texture_storage_2d<rgba32uint, read>;

@fragment
fn main(@builtin(position) screenPos : vec4f) -> @location(0) vec4f {
    let packed = textureLoad(packedTexture, vec2i(floor(screenPos.xy)));
    var albedo: vec3u;
    albedo.r = packed.x & 0xFF;
    albedo.g = (packed.x >> 8) & 0xFF;
    albedo.b = (packed.x >> 16) & 0xFF;
    var position: vec3f;
    var normal: vec3f;

    position.x  = unpack2x16float(packed.y).x;
    position.y  = unpack2x16float(packed.y).y;
    position.z  = unpack2x16float(packed.z).x;
    normal.x    = unpack2x16float(packed.z).y;
    normal.y   = unpack2x16float(packed.w).x;
    normal.z   = unpack2x16float(packed.w).y;

    let clusterPos = calculateClusterPos(position, &cameraUniforms, clusterSet.numClusters);

    let clusterIdx = calculateClusterIdx(clusterPos, clusterSet.numClusters);

    let cluster = &clusterSet.clusters[clusterIdx];
    var totalLightContrib = vec3f(0, 0, 0);
    for (var i = 0u; i < (*cluster).numLights; i++) {
        let lightIdx = (*cluster).lightIndices[i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, position, normal);
    }

    let finalColor = vec3f(albedo) / 255 * totalLightContrib;
    return vec4f(finalColor, 1);
}