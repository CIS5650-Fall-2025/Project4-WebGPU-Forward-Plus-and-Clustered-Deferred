// ─────────────────────────────────────────────────────────────
// Fragment Shader: Encodes Normal and Diffuse Color
//   • Samples a diffuse texture
//   • Performs alpha cutout
//   • Packs RGB color into a single float via naive encoding
// ─────────────────────────────────────────────────────────────

// Camera uniform (not used in current logic, reserved for future extensions)
@group(${bindGroup_scene}) @binding(0) var<uniform> camera: CameraUniforms;

// Diffuse texture and sampler
@group(${bindGroup_material}) @binding(0) var uTex: texture_2d<f32>;

@group(${bindGroup_material}) @binding(1) var uSampler: sampler;

// Input struct from vertex output / interpolated data
struct FragmentInput {
    @location(0) fragWorldPos: vec3f,
    @location(1) fragNormal: vec3f,
    @location(2) fragUV: vec2f
};


@fragment
fn main(input: FragmentInput) -> @location(0) vec4f {
    // Sample base color texture
    let baseColor: vec4f = textureSample(uTex, uSampler, input.fragUV);

    // Alpha cutout (discard fragment if too transparent)
    if (baseColor.a < 0.5) {
        discard;
    }

    // Encode RGB into a single float via naïve fixed-point packing
    let r = u32(clamp(baseColor.r * 1000.0, 0.0, 1000.0));
    let g = u32(clamp(baseColor.g * 1000.0, 0.0, 1000.0));
    let b = u32(clamp(baseColor.b * 1000.0, 0.0, 1000.0));
    let packedRGB = f32(r + g * 1000u + b * 1000000u);

    // Output: XYZ = normal, W = packed RGB
    return vec4f(input.fragNormal, packedRGB);
}
