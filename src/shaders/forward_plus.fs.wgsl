// ─────────────────────────────────────────────────────────────
// Forward+ Fragment Shader
//   • Uses clustered light list instead of brute-force loop
//   • Outputs lit color (no post-processing)
// ─────────────────────────────────────────────────────────────

// Scene-space resources
@group(${bindGroup_scene}) @binding(0) var<uniform>  camera      : CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> uLightSet   : LightSet;

// Diffuse texture
@group(${bindGroup_material}) @binding(0) var uDiffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var uSampler: sampler;

// Cluster Grid
@group(${bindGroup_lightClusters}) @binding(0) var<uniform> uClusterGrid : vec4<u32>;
@group(${bindGroup_lightClusters}) @binding(3) var<storage, read_write> uLightIndices: ClusterLightIndexBuffer;


// Vertex-to-fragment interpolated inputs
struct FragmentInput {
    @location(0) worldPos : vec3f,  // World-space position
    @location(1) normal   : vec3f,  // World-space normal
    @location(2) uv       : vec2f   // Texture coordinates
};



@fragment fn main(data: FragmentInput) -> @location(0) vec4f {
    // Project to clip space and then to NDC
    let clipPos = camera.viewProjMat * vec4(data.worldPos, 1.0f);
    let screenUV = clipPos.xy / clipPos.w * 0.5 + vec2(0.5);
    
    // Logarithmic depth for better Z clustering
    let depth = log(clipPos.z / camera.cameraParams.x) / log(camera.cameraParams.y / camera.cameraParams.x);
    
    // Compute 3D cluster coordinates
    let clusterX = u32(floor(screenUV.x * f32(uClusterGrid.x)));
    let clusterY = u32(floor(screenUV.y * f32(uClusterGrid.y)));
    let clusterZ = u32(floor(depth * f32(uClusterGrid.z)));
    
    // Flatten to 1D cluster index
    let clusterIndex = clusterX +
                       clusterY * uClusterGrid.x +
                       clusterZ * uClusterGrid.x * uClusterGrid.y;


    // Offset in the flat light index buffer
    let indexOffset = clusterIndex * uClusterGrid.w;
    
    // Sample base color from diffuse texture
    let baseColor = textureSample(uDiffuseTex, uSampler, data.uv);

    // Alpha test (discard transparent fragments)
    if (baseColor.a < 0.5) {
        discard;
    }
    
    var lighting = vec3f(0.0);
    for (var i = 0u; i < uClusterGrid.w; i++) {
        let lightIndex = uLightIndices.indices[indexOffset + i];

        // Sentinel check (end of list)
        if (lightIndex == 2 << 30) {
            break;
        }

        let light = uLightSet.lights[lightIndex];
        lighting += calculateLightContrib(light, data.worldPos, data.normal);
    }
    
    
    return vec4(baseColor.rgb * lighting, 1.0f);
}
