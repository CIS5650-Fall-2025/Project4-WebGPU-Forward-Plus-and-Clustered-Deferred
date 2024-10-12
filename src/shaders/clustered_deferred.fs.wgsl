// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

@group(${bindGroupGbuffer}) @binding(0) var defultSampler: sampler;
@group(${bindGroupGbuffer}) @binding(1) var positionBuffer: texture_storage_2d<rgb32float, write>;
@group(${bindGroupGbuffer}) @binding(2) var normalBuffer: texture_storage_2d<rgb32float, write>;
@group(${bindGroupGbuffer}) @binding(3) var albedoBuffer: texture_storage_2d<rgb32float, write>;

struct FragmentInput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput)
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }
    let canvasSize = textureDimensions(positionBuffer);
    let coords = vec2<i32>(in.fragPos.xy * vec2<f32>(canvasSize) - vec2<f32>(0.5));
    let normalEncoded = normalize(in.nor) * 0.5 + 0.5;
    textureStore(positionBuffer, coords, vec4<f32>(in.pos, 1.0));
    textureStore(normalBuffer, coords, vec4<f32>(normalEncoded, 1.0));
    textureStore(albedoBuffer, coords, vec4<f32>(diffuseColor, 1.0));
}
