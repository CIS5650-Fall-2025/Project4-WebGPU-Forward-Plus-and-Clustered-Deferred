// DONE-3: implement the Clustered Deferred G-buffer fragment shader
// This shader should only store G-buffer information and should not do any shading.
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraProps;
@group(${bindGroup_material}) @binding(0) var diffuseTexture: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTextureSampler: sampler;

// Structure to store the input data for the fragment shader
struct FragmentInput {
    @location(0) point: vec3f,
    @location(1) normal: vec3f,
    @location(2) coordinate: vec2f
};

// Fragment shader to process the diffuse color and compute intermediate data
@fragment fn main(data: FragmentInput) -> @location(0) vec4f {
    
    // Sample the diffuse color from the texture using the provided coordinates
    var color = textureSample(
        diffuseTexture,
        diffuseTextureSampler,
        data.coordinate
    );
    
    // Quantize the color channels (r, g, b) and pack them into a single floating-point value for storage
    let r = u32(clamp(color.r * 1000.0f, 0.0f, 1000.0f));
    let g = u32(clamp(color.g * 1000.0f, 0.0f, 1000.0f));
    let b = u32(clamp(color.b * 1000.0f, 0.0f, 1000.0f));

    // Combine the quantized color components into a single float
    let a = f32(r + g * 1000 + b * 1000 * 1000);
    
    // Return the normal components and the packed color value
    return vec4(
        data.normal.x, // Normal x component
        data.normal.y, // Normal y component
        data.normal.z, // Normal z component
        a              // Packed color value
    );
}
