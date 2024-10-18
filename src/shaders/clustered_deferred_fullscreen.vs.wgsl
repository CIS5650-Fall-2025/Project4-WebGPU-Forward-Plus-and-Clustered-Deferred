// TODO-3: implement the Clustered Deferred fullscreen vertex shader

// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.
// CHECKITOUT: you can use this vertex shader for all of the renderers

// TODO-1.3: add a uniform variable here for camera uniforms (of type CameraUniforms)
// make sure to use ${bindGroup_scene} for the group
// camera uniforms are bind to slot 0 in the bind group
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_model}) @binding(0) var<uniform> modelMat: mat4x4f;

struct VertexInput
{
    @builtin(vertex_index) vertexIndex: u32,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct VertexOutput
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f,
    @location(1) pos_ndc: vec3f,
    @location(2) pos_view: vec3f
}

@vertex
fn main(in: VertexInput) -> VertexOutput
{
    let modelPos = modelMat * vec4(in.pos, 1); // World space position

    var positions = array<vec2<f32>, 3>(
        vec2<f32>(-1.0, -1.0),  
        vec2<f32>(-1.0, 3.0),   
        vec2<f32>(3.0, -1.0)     
    );

    var texCoords = array<vec2<f32>, 3>(
        vec2<f32>(0.0, 1.0),  
        vec2<f32>(0.0, -1.0),   
        vec2<f32>(2.0, 1.0)     
    );

    var out: VertexOutput;

    let vertexIndex = in.vertexIndex;
    out.fragPos = vec4<f32>(positions[vertexIndex], 0.0, 1.0);
    out.uv = texCoords[vertexIndex];

    // out.fragPos = cameraUniforms.viewProj * modelPos; // Clip space pos
    let pos_ClipSpace = cameraUniforms.viewProj * modelPos; // Clip space pos
    out.pos_ndc = pos_ClipSpace.xyz / pos_ClipSpace.w; // NDC space position
    out.pos_view = (cameraUniforms.view * modelPos).xyz; // View space position

    return out;
}
