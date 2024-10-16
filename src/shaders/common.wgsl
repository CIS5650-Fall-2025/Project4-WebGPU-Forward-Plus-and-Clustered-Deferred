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
    minDepth: vec3<f32>,
    maxDepth: vec3<f32>,
    numLights: u32,
    lightIndices: array<u32, ${MAX_LIGHTS_PER_CLUSTER}>
    
}

struct ClusterSet {
    numClusters: u32,
    clusters: array<Cluster>
}


struct CameraUniforms {
    viewProjMat: mat4x4<f32>,
    viewMat:  mat4x4<f32>,
    invProjMat: mat4x4<f32>,
    clusterGridSize: vec3<u32>,
    canvasResolution: vec2<f32>,
    nearPlane: f32,
    farPlane: f32    
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

fn sqDistPointAABB(_point : vec3<f32>, minAABB : vec3<f32>, maxAABB : vec3<f32>) -> f32 {
    var sqDist = 0.0;
    
    for(var i = 0; i < 3; i = i + 1) {
      let v = _point[i];
      if(v < minAABB[i]){
        sqDist = sqDist + (minAABB[i] - v) * (minAABB[i] - v);
      }
      if(v > maxAABB[i]){
        sqDist = sqDist + (v - maxAABB[i]) * (v - maxAABB[i]);
      }
    }

    return sqDist;
}


fn lineIntersectionToZPlane(a: vec3<f32>, b: vec3<f32>, zDistance: f32) -> vec3<f32> {
    let normal = vec3<f32>(0.0, 0.0, 1.0);
    let ab = b - a;
    let t = (zDistance - dot(normal, a)) / dot(normal, ab);
    return a + t * ab;
}