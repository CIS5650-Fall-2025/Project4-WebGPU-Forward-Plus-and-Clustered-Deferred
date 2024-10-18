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

    if (albedo.x > 0.9) {
        albedo.x = 1.0;
    } else if (albedo.x > 0.5) {
        albedo.x = 0.7;
    } else if (albedo.x > 0.3) {
        albedo.x = 0.4;
    } else if (albedo.x > 0.05) {
        albedo.x = 0.2;
    } else if (albedo.x > 0.01) {
        albedo.x = 0.03;
    } else {
        albedo.x = 0.0;
    }

    if (albedo.y > 0.9) {
        albedo.y = 1.0;
    } else if (albedo.y > 0.5) {
        albedo.y = 0.7;
    } else if (albedo.y > 0.3) {
        albedo.y = 0.4;
    } else if (albedo.y > 0.05) {
        albedo.y = 0.2;
    } else if (albedo.y > 0.01) {
        albedo.y = 0.03;
    } else {
        albedo.y = 0.0;
    }

    if (albedo.z > 0.9) {
        albedo.z = 1.0;
    } else if (albedo.z > 0.5) {
        albedo.z = 0.7;
    } else if (albedo.z > 0.3) {
        albedo.z = 0.4;
    } else if (albedo.z > 0.05) {
        albedo.z = 0.2;
    } else if (albedo.z > 0.01) {
        albedo.z = 0.03;
    } else {
        albedo.z = 0.0;
    }

    textureStore(outputTex, pos, vec4f(albedo, 1.0));
}