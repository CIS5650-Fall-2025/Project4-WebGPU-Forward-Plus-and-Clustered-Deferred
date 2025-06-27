// CHECKITOUT: you can use this vertex shader for all of the renderers

// Declare the camera's uniform variable
@group(${bindGroup_scene}) @binding(0)
var<uniform> camera: CameraUniforms;

@group(${bindGroup_model}) @binding(0)
var<uniform> modelMat: mat4x4f;

struct VertexInput {
    @location(0) pos: vec3f,  // obj-space position
    @location(1) nor: vec3f, // obj-space normal
    @location(2) uv: vec2f
}

struct VertexOutput {
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f, // world-space position
    @location(1) nor: vec3f, // world-space normal
    @location(2) uv: vec2f
}

@vertex
fn main(in: VertexInput) -> VertexOutput {
    let modelPos = modelMat * vec4(in.pos, 1);
    let modelNor = normalize((modelMat * vec4(in.nor, 0.0)).xyz);

    var out: VertexOutput;
    out.fragPos = camera.viewProjMat * modelPos;
    out.pos = modelPos.xyz / modelPos.w;  // world space
    out.nor = modelNor;                   // world space
    out.uv = in.uv;
    return out;
}
