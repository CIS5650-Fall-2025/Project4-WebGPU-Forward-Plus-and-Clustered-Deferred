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
struct ClusterSet{
    minAABB: vec3<f32>,
    maxAABB: vec3<f32>,
    lightCount: u32,
    lightIndices: array<u32, ${maxNumLightsPerCluster}>,
}

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProjMat: mat4x4f,
    invViewProjMat: mat4x4f,
    projMat: mat4x4f,
    invProjMat: mat4x4f,
    viewMat: mat4x4f,
    invViewMat: mat4x4f
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

fn getClusterIndex(pos_world: vec3f, camera: CameraUniforms) -> u32 {
    let pos4_ndc = camera.viewProjMat * vec4<f32>(pos_world, 1.0);
    let pos_ndc = pos4_ndc.xyz / pos4_ndc.w;

    let xIndex = u32((pos_ndc.x * 0.5 + 0.5) * ${clusteringCountX});
    let yIndex = u32((pos_ndc.y * 0.5 + 0.5) * ${clusteringCountY});

    let Z_view = (camera.viewMat * vec4<f32>(pos_world, 1.0)).z;
    let zIndex = u32(log(Z_view / -f32(${nearClip})) / log(f32(${farClip}) / f32(${nearClip})) * f32(${clusteringCountZ}));
    let index = xIndex + yIndex * ${clusteringCountX} + zIndex * ${clusteringCountX} * ${clusteringCountY};

    return index;
}

