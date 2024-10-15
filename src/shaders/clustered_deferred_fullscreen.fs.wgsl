// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterLights: array<u32>;

@group(1) @binding(0) var positionTex: texture_2d<f32>;
@group(1) @binding(1) var normalTex: texture_2d<f32>;
@group(1) @binding(2) var albedoTex: texture_2d<f32>;

@fragment
fn main(@builtin(position) fragCoord: vec4f) -> @location(0) vec4f {
    let uv = fragCoord.xy / vec2f(cameraUniforms.screenWidth, cameraUniforms.screenHeight);

    let pos = textureLoad(positionTex, vec2i(fragCoord.xy), 0).xyz;
    let nor = textureLoad(normalTex, vec2i(fragCoord.xy), 0).xyz;
    let albedo = textureLoad(albedoTex, vec2i(fragCoord.xy), 0).rgb;

    let screenWidth = cameraUniforms.screenWidth;
    let screenHeight = cameraUniforms.screenHeight;

    let xCluster = u32(fragCoord.x / screenWidth * f32(${clusterCountX}));
    let yCluster = u32(fragCoord.y / screenHeight * f32(${clusterCountY}));

    let depth = -pos.z;

    let zCluster = u32((depth - cameraUniforms.nearPlane) / (cameraUniforms.farPlane - cameraUniforms.nearPlane) * f32(${clusterCountZ}));

    let clusterIdX = clamp(xCluster, 0u, ${clusterCountX}u - 1u);
    let clusterIdY = clamp(yCluster, 0u, ${clusterCountY}u - 1u);
    let clusterIdZ = clamp(zCluster, 0u, ${clusterCountZ}u - 1u);

    let clusterIndex = clusterIdX + clusterIdY * ${clusterCountX}u + clusterIdZ * ${clusterCountX}u * ${clusterCountY}u;
    let clusterOffset = clusterIndex * (1u + ${maxLightsPerCluster}u);

    let numLights = clusterLights[clusterOffset];

    var totalLightContrib = vec3f(0.0, 0.0, 0.0);

    for (var i = 0u; i < numLights; i = i + 1u) {
        let lightIdx = clusterLights[clusterOffset + 1u + i];
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, pos, nor);
    }

    var finalColor = albedo * totalLightContrib;
    return vec4(finalColor, 1.0);
}