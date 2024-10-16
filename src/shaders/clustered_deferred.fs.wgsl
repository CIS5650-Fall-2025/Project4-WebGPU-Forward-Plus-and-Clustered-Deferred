// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var albedoTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(3) var normalTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var positionTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(5) var gbufferSampler: sampler;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;




struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}


@fragment
fn main(in: FragmentInput, @builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4f
{

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    return vec4(vec3(0), 1);
}