// This shader should only store G-buffer information and should not do any shading.
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput {
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4u {
    // Get albedo from texture
    let albedo = textureSample(diffuseTex, diffuseTexSampler, in.uv);

    let albedoInt = vec4u(255 * albedo);

    var packed: vec4u;
    packed.x = albedoInt.r + (albedoInt.g << 8) + (albedoInt.b << 16) + (albedoInt.a << 24);
    packed.y = pack2x16float(vec2f(in.pos.x, in.pos.y));
    packed.z = pack2x16float(vec2f(in.pos.z, in.nor.x));
    packed.w = pack2x16float(vec2f(in.nor.y, in.nor.z));

    return packed;
}