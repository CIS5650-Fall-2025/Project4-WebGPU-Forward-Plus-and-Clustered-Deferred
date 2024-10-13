// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraData: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var gbufferAlbedoTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(2) var gbufferNormalTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(3) var gbufferPositionTex: texture_2d<f32>;

struct FragmentInput {
    @location(0) texCoord: vec2<f32>,
    @builtin(position) fragCoord: vec4<f32>
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    return vec4(1, 0, 0, 1);
}