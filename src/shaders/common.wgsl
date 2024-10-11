// CHECKITOUT: code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}


// TODO-2: you may want to create a ClusterSet struct similar to LightSet
struct Cluster {
    minPos: vec4f, //Avoid using vec3f to avoid padding
    maxPos: vec4f,
    numLights: u32,
    lightIndices: array<u32,100> //I need to know the maximum number of lights per cluster
}

struct ClusterSet {
    //numClusters: u32,
    clusters: array<Cluster,512> //I need to know the maximum number of clusters
}

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProjMat: mat4x4f
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
