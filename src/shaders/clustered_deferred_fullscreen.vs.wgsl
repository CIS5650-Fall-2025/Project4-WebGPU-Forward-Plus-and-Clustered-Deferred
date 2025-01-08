// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.
@group(${bindGroup_model}) @binding(0) var<uniform> modelMat: mat4x4f;
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;

struct VertexInput {
    @location(0) pos: vec4f,
    @location(1) alb: vec4f,
    @location(2) nor: vec4f
}

@vertex
fn main(in: VertexInput) -> VertexOutput {
    let modelPos = modelMat * vec4(in.pos, 1);

    var out: VertexOutput;
    out.fragPos = cameraUniforms.viewProjMat * in.pos;
    out.posWorld = in.pos.xyz;
    out.nor = in.nor;
    out.uv = in.uv;
    return out;
}