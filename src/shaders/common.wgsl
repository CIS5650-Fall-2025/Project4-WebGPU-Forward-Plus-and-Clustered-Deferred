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
    numLights: u32,
    lights: array<u32, ${maxNumLightsPerCluster}>
}

struct ClusterSet {
    clusters: array<Cluster, ${numClusterX} * ${numClusterY} * ${numClusterZ}>
}

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewproj : mat4x4f,
    view : mat4x4f,
    projInv : mat4x4f,
    nearFar : vec2<f32>,
}

// CHECKITOUT: this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    // return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
    let val = clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
    if (val > 0.0) {
        return 1.0;
    }
    return 0.0;
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

fn applyTransform(p: vec4<f32>, transform: mat4x4<f32>) -> vec3<f32> {
    let transformed = transform * p;
    return transformed.xyz / transformed.w;
}

// https://stackoverflow.com/a/4579069
fn intersectionTest(S: vec3<f32>, r: f32, C1: vec3<f32>, C2: vec3<f32>) -> bool {
    var dist_squared = r * r;
    /* assume C1 and C2 are element-wise sorted, if not, do that now */
    // if (S.x < C1.x) {
    //     dist_squared -= (S.x - C1.x) * (S.x - C1.x);
    // }
    // else if (S.x > C2.x) {
    //     dist_squared -= (S.x - C2.x) * (S.x - C2.x);
    // }

    // if (S.y < C1.y) {
    //     dist_squared -= (S.y - C1.y) * (S.y - C1.y);
    // }
    // else if (S.y > C2.y) {
    //     dist_squared -= (S.y - C2.y) * (S.y - C2.y);
    // }

    // if (S.z < C1.z) {
    //     dist_squared -= (S.z - C1.z) * (S.z - C1.z);
    // }
    // else if (S.z > C2.z) {
    //     dist_squared -= (S.z - C2.z) * (S.z - C2.z);
    // }
    
    // return dist_squared > 0.0;
    let closestPoint = clamp(S, C1, C2);
    let vecToClosestPoint = closestPoint - S;
    let distanceSquared = dot(vecToClosestPoint, vecToClosestPoint);
    return distanceSquared < dist_squared;
}