// Fragment shader
@group(0) @binding(0) var depthTexture: texture_depth_2d;
@group(0) @binding(1) var depthSampler: sampler;

struct FragmentInput
{
    @location(0) uv: vec2f
}

@fragment
fn fs_main(in: FragmentInput) -> @location(0) vec4<f32> {
    let texCoords = in.uv.xy; // 示例中直接使用中心点，实际中应使用适当的坐标
    var depth = textureSample(depthTexture, depthSampler, in.uv);
    //return vec4(in.uv, 0.0, 1.0);
    depth = pow(depth, 50);
    return vec4<f32>(vec3(depth), 1.0);
}