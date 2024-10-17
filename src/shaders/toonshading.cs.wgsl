@group(${bindGroup_scene}) @binding(0) var inputTex : texture_2d<f32>;
@group(${bindGroup_scene}) @binding(1) var outputTex : texture_storage_2d<${presentationFormat}, write>;

@compute
@workgroup_size(1, 1)
fn main(@builtin(global_invocation_id) globalIdx: vec3u) {
    var albedo = textureLoad(
        inputTex,
        vec2i(globalIdx.xy),
        0
    ).xyz;
    let pos = globalIdx.xy;

    if (albedo.x > 0.66) {
        albedo.x = 1.0;  // Brightest band
    } else if (albedo.x > 0.33) {
        albedo.x = 0.66; // Mid-tone band
    } else if (albedo.x > 0.1) {
        albedo.x = 0.33; // Darkest band
    } else {
        albedo.x = 0.0;
    }

    if (albedo.y > 0.66) {
        albedo.y = 1.0;  // Brightest band
    } else if (albedo.y > 0.33) {
        albedo.y = 0.66; // Mid-tone band
    } else if (albedo.y > 0.1) {
        albedo.y = 0.33; // Darkest band
    } else {
        albedo.y = 0.0;
    }

    if (albedo.z > 0.66) {
        albedo.z = 1.0;  // Brightest band
    } else if (albedo.z > 0.33) {
        albedo.z = 0.66; // Mid-tone band
    } else if (albedo.z > 0.1) {
        albedo.z = 0.33; // Darkest band
    } else {
        albedo.z = 0.0;
    }

    textureStore(outputTex, pos, vec4f(albedo, 1.0));
}