// ─────────────────────────────────────────────────────────────
// Fragment Shader: Clustered Lighting Resolve
//   • Decodes normal and diffuse color from intermediate texture
//   • Uses depth texture to reconstruct world position
//   • Performs clustered lighting accumulation
// ─────────────────────────────────────────────────────────────

struct FragmentInput {
    @location(0) uv: vec2f  // Screen-space UV coordinate
};

@group(0) @binding(0) var<uniform> camera: CameraUniforms;

// Intermediate texture (packed normal + encoded color)
@group(0) @binding(1) var uGBuffer: texture_2d<f32>;
@group(0) @binding(2) var uGBufferSampler: sampler;

// Depth texture
@group(0) @binding(3) var uDepthTexture: texture_2d<f32>;

@group(0) @binding(4) var<storage, read> uLightSet: LightSet;

// Cluster grid parameters (x, y, z, maxLightsPerCluster)
@group(1) @binding(0) var<uniform> uClusterGrid: vec4<u32>;

// Clustered light index buffer
@group(1) @binding(3) var<storage, read_write> uClusterIndices: ClusterLightIndexBuffer;


@group(2) @binding(0) var<uniform> uDebugMode: u32;




// declare the fragment shader
@fragment fn main(input: FragmentInput) -> @location(0) vec4f {
    
    // acquire the intermediate color
    var gBufferSample = textureSample(uGBuffer, uGBufferSampler, input.uv);
    //let gBufferSample = textureSample(uGBuffer, uGBufferSampler, input.uv);
    var normal = gBufferSample.rgb;
    

    let encodedColor = gBufferSample.a;
    let b = floor(encodedColor / (1000.0f * 1000.0f));
    let g = floor((encodedColor - b * 1000.0f * 1000.0f) / 1000.0f);
    let r = (encodedColor - g * 1000.0f - b * 1000.0f * 1000.0f);
    gBufferSample = vec4f(vec3f(r, g, b) / 1000.0f, 1.0f);

    var albedo = vec3f(r, g, b) / 1000.0;

    
    var depthValue  = textureSample(
        uDepthTexture,
        uGBufferSampler,
        input.uv
    ).r;

    let ndc = vec4f(
        input.uv * 2.0 - vec2f(1.0, 1.0),
        depthValue,
        1.0
    );

    

    var viewPos  = camera.invViewProjMat * ndc;
    viewPos  /= viewPos.w;
    var worldPos = camera.invViewMat * vec4f(viewPos.xyz, 1.0f);

    // ─ Compute cluster index ─
    let clipPos = camera.viewProjMat * vec4f(worldPos.xyz, 1.0);
    let clipXY = clipPos.xy / clipPos.w;
    
    let linearDepth  = log(clipPos.z / camera.cameraParams.x) / log(camera.cameraParams.y / camera.cameraParams.x);

    let clusterX = u32(clamp(floor((clipXY.x * 0.5 + 0.5) * f32(uClusterGrid.x)), 0.0, f32(uClusterGrid.x - 1)));
    let clusterY = u32(clamp(floor((clipXY.y * 0.5 + 0.5) * f32(uClusterGrid.y)), 0.0, f32(uClusterGrid.y - 1)));
    let clusterZ = u32(clamp(floor(linearDepth * f32(uClusterGrid.z)), 0.0, f32(uClusterGrid.z - 1)));

    let clusterIndex  = clusterX + clusterY * uClusterGrid.x + clusterZ * uClusterGrid.x * uClusterGrid.y;
    let maxLights = uClusterGrid.w;
    let lightOffset = clusterIndex * maxLights;

   
    // ─ Accumulate lighting ─
    var lightAccum = vec3f(0.0);
    var count = 0u;

   
    loop {
        if (count >= maxLights) { break; }

        let lightIndex = uClusterIndices.indices[lightOffset + count];
        if (lightIndex == 0xffffffffu) { break; }

        let light = uLightSet.lights[lightIndex];
        lightAccum += calculateLightContrib(light, worldPos.xyz, normal);

        count += 1u;
    }
    

    //Debugging
    if (uDebugMode == 1u) {
        // Compute screen-space grid coordinates
        let gridCoord = input.uv * vec2f(f32(uClusterGrid.x), f32(uClusterGrid.y));

        // Compute border lines
        let borderX = fract(gridCoord.x);
        let borderY = fract(gridCoord.y);
        let lineWidth = 0.015; // Thickness of debug grid lines

        let isOnBorder = step(1.0 - lineWidth, borderX) + step(1.0 - lineWidth, borderY);
        let gridLineColor = vec3f(1.0, 0.0, 0.0); // Red

        // Blend debug grid lines into final color
        let debugColor = mix(albedo * lightAccum, gridLineColor, clamp(isOnBorder, 0.0, 1.0));

        return vec4f(debugColor, 1.0);
    }

    return vec4f(albedo * lightAccum, 1.0);
}