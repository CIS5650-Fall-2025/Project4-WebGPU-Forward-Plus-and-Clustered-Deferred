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

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProjMat: mat4x4f,
    inverseProjMatrix: mat4x4f,
    outputSize: vec2<f32>,
    zNear: f32,
    zFar: f32
}

struct ViewUniforms {
    matrix : mat4x4<f32>,
    position : vec3<f32>
};

struct ClusterLights {
  offset : u32,
  count : u32
};

struct ClusterLightGroup {
  offset : atomic<u32>,
  lights : array<ClusterLights, 27648>,
  indices : array<u32, 27648*${clusterMaxLights}>
};

struct ClusterBounds {
  minAABB : vec3<f32>,
  maxAABB : vec3<f32>
};

struct Clusters {
  bounds : array<ClusterBounds, 27648>
};

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