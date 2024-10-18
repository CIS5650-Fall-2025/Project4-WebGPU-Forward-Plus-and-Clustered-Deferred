// TODO-3: implement the Clustered Deferred G-buffer fragment shader

// This shader should only store G-buffer information and should not do any shading.

@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct FragmentOutput
{
    @location(0) unity: vec4u,
    @location(1) debug: vec4f
}

@fragment
fn main(in: FragmentInput, @builtin(position) fragCoord: vec4<f32>) -> FragmentOutput
{
    var out: FragmentOutput;

    var diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    // var debugVal = fragCoord.z * f32(0xFFFF);
    // debugVal.x = f32(u32(debugVal.x) & 0xFFFF) / f32(0xFFFF);
    // debugVal.y = f32(u32(debugVal.y) & 0xFFFF) / f32(0xFFFF);
    // debugVal.z = f32(u32(debugVal.z) & 0xFFFF) / f32(0xFFFF);
    // out.debug = vec4(vec3(f32(fragCoord.z)), 1.0);



    var maskfront = u32(0xFFFF0000);
    var maskback = u32(0x0000FFFF);
    var rmask = u32(0xFF000000);
    var gmask = u32(0x00FF0000);
    var bmask = u32(0x0000FF00);
    var amask = u32(0x000000FF);

    var nor = ((in.nor + 1.0) * 0.5) * f32(0xFFFF); // remember to pack the normal
    diffuseColor = diffuseColor * f32(0xFF);
    var depth = fragCoord.z * f32(0xFFFF);
    // populate G-buffer
    out.unity.r = ((u32(nor.x) << 16) & maskfront) | (u32(nor.y) & maskback);
    out.unity.g = ((u32(nor.z) << 16) & maskfront) | (u32(depth) & maskback);
    out.unity.b = ((u32(diffuseColor.r) << 24) & rmask) | ((u32(diffuseColor.g) << 16) & gmask) | ((u32(diffuseColor.b) << 8) & bmask) | (u32(diffuseColor.a) & amask);


    return out;
}