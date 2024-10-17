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
    let uv = vec2f(fragCoord.x, 1-fragCoord.y);

    let pos = textureLoad(positionTex, vec2i(fragCoord.xy), 0).xyz;
    let nor = textureLoad(normalTex, vec2i(fragCoord.xy), 0).xyz;
    let albedo = textureLoad(albedoTex, vec2i(fragCoord.xy), 0).rgb;

    let screenWidth = cameraUniforms.screenWidth;
    let screenHeight = cameraUniforms.screenHeight;

    let xCluster = u32(fragCoord.x / screenWidth * f32(${clusterCountX}));
    let yCluster = u32(fragCoord.y / screenHeight * f32(${clusterCountY}));

    // Calculate cluster indices using logarithmic depth
    let logRatio = cameraUniforms.farPlane / cameraUniforms.nearPlane;
    var zClusterF32: f32;
    
    var viewPos =  cameraUniforms.viewMat * vec4f(pos, 1.0);
    let depth = -viewPos.z;
    //var depth = -pos.z;
    let depthClamped = clamp(depth, cameraUniforms.nearPlane, cameraUniforms.farPlane);
    zClusterF32 = (log(depthClamped / cameraUniforms.nearPlane) / log(logRatio)) * f32(${clusterCountZ});

    var zCluster = u32((floor(zClusterF32)));

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
    //return vec4(f32(xCluster)/100.0,f32(yCluster)/100.0,0.0, 1.0);
}