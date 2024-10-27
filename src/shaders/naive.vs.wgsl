// CHECKITOUT: you can use this vertex shader for all of the renderers

// TODO-1.3: add a uniform variable here for camera uniforms (of type CameraUniforms)
// make sure to use ${bindGroup_scene} for the group

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUnifs: CameraUniforms;
@group(${bindGroup_model}) @binding(0) var<uniform> modelMat: mat4x4f;

struct VertexInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{

    let modelPos = modelMat * vec4(in.pos, 1);

    var out: VertexOutput;
    out.fragPos = cameraUnifs.viewProjMat * modelPos; // TODO-1.3: replace ??? with the view proj mat from your CameraUniforms uniform variable
    out.pos = modelPos.xyz / modelPos.w;
    out.nor = in.nor;
    // out.nor = vec3f(cameraUnifs.farPlane);
    out.uv = in.uv;
    // if (cameraUnifs.nearPlane == 69) {
    //     // return vec4(1,0,0,1);
    //     out.pos.x = 1.0;
    // } else {
    //     out.pos.x = 0.0;
    //     // return vec4(1,1,1,1);
    // }
    return out;
}
