// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraData: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var gbufferAlbedoTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(2) var gbufferNormalTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(3) var gbufferPositionTex: texture_2d<f32>;
@group(${bindGroup_scene}) @binding(4) var gbufferAlbedoSampler: sampler;
@group(${bindGroup_scene}) @binding(5) var gbufferNormalSampler: sampler;
@group(${bindGroup_scene}) @binding(6) var gbufferPositionSampler: sampler;

struct FragmentInput {
    @location(0) uv: vec2<f32>,
    @builtin(position) fragCoord: vec4<f32>
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let flippedUV = vec2<f32>(in.uv.x, 1.0 - in.uv.y);
    let albedo = textureSample(gbufferAlbedoTex, gbufferAlbedoSampler, flippedUV);
    let normal = textureSample(gbufferNormalTex, gbufferNormalSampler, flippedUV);
    let position = textureSample(gbufferPositionTex, gbufferPositionSampler, flippedUV);

    return normal;
}