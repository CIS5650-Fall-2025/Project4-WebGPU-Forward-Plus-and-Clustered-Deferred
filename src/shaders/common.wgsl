// CHECKITOUT: code that you add here will be prepended to all shaders
struct Light {
    pos: vec3f,
    color: vec3f,
    // TODO-2
}
struct LightSet {
    numLights: u32,
    lights: array<Light>
}
// TODO-2: you may want to create a ClusterSet struct similar to LightSet
struct ClusterSet {
    numLights: u32, // num of lights per cluster 
    lightIndices: array<u32>,
}

struct CameraUniforms {
    viewProjMat: mat4x4f,
    // TODO-2
    inverseViewProjMat: mat4x4f,
    near: f32,
    far: f32,
    screenSize: vec2f,
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}
