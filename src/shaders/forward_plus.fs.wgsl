// DONE-2: implement the Forward+ fragment shader

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

@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraProps;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lights: LightSet;
@group(${bindGroup_material}) @binding(0) var diffuseTexture: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTextureSampler: sampler;
@group(${bindGroup_clustering}) @binding(0) var<uniform> clusterGrid: vec4<u32>;

@group(${bindGroup_clustering}) @binding(3)
var<storage, read_write> clusterSet: ClusterSet;

struct FragmentInput {
    @location(0) point: vec3f,        // Fragment's world-space position
    @location(1) normal: vec3f,       // Fragment's surface normal
    @location(2) coordinate: vec2f    // Texture coordinates for sampling
};

// Fragment shader
@fragment fn main(input: FragmentInput) -> @location(0) vec4f {
    
    // Transform fragment position to camera space
    let position = camera.viewProjMat * vec4(input.point, 1.0f);
    
    // Compute the pixel-space coordinate (renamed to screenCoord to avoid conflict)
    let screenCoord = position.xy / position.w;
    
    // Calculate the linear depth using the camera projection
    let depth = log(position.z / camera.camera.x) / log(camera.camera.y / camera.camera.x);
    
    // Compute the X, Y, and Z indices of the cluster based on screen space and depth
    let x = u32(floor((screenCoord.x * 0.5f + 0.5f) * f32(clusterGrid.x)));
    let y = u32(floor((screenCoord.y * 0.5f + 0.5f) * f32(clusterGrid.y)));
    let z = u32(floor(depth * f32(clusterGrid.z)));
    
    // Calculate the cluster index
    let index = x + y * clusterGrid.x + z * clusterGrid.x * clusterGrid.y;
    
    // Compute the start index for the lights to iterate
    let startIndex = index * clusterGrid.w;
    
    // Sample the diffuse texture
    var color = textureSample(diffuseTexture, diffuseTextureSampler, input.coordinate);
    
    // Initialize total light contribution
    var totalLightContribution = vec3f(0.0f, 0.0f, 0.0f);

    // Define an early exit value in case of invalid index
    var INVALID_INDEX_THRESHOLD = 2u << 30;
    
    // Iterate over all lights in the cluster
    for (var count : u32 = 0; count < clusterGrid.w; count += 1) {
        // Retrieve the current light's index
        let light_index = clusterSet.lightIndices[startIndex + count];
        
        // Exit loop early if we encounter an invalid index value!
        // This made a huge difference in performance!
        if (light_index == INVALID_INDEX_THRESHOLD) 
        {
            break;
        }
        
        // Get the current light properties
        let light = lights.lights[light_index];
        
        // Accumulate the light's contribution to the total
        totalLightContribution = totalLightContribution + 
        calculateLightContrib(
            light, 
            input.point, 
            input.normal
        );
    }
    
    // Multiply the fragment’s diffuse color by the accumulated light contribution.
    // Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
    return vec4(color.rgb * totalLightContribution, 1.0f);
}
