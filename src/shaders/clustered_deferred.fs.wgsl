// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput {
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct FragmentOutput {
    @location(0) pos: vec4f,
    @location(1) alb: vec4f,
    @location(2) nor: vec4f
}

@fragment
fn main(in: FragmentInput) -> FragmentOutput {
    let albedo = textureSample(diffuseTex, diffuseTexSampler, in.uv);

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return FragmentOutput(
        vec4f(pos, 1.0),
        albedo,
        vec4f(normal, 1.0)
    );
}