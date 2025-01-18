// code that you add here will be prepended to all shaders

struct Light {
    pos: vec3f,
    color: vec3f
}

struct LightSet {
    numLights: u32,
    lights: array<Light>
}

struct Cluster {
    numLights: u32,
    lightIndices: array<u32, ${maxLightsPerCluster}>
}

struct ClusterSet {
    numClusters: vec3u,
    clusters: array<Cluster>
}

struct CameraUniforms {
    viewProjMat: mat4x4f,
    projMat: mat4x4f,
    viewMat: mat4x4f,
    clipPlanes: vec2f
}

// this special attenuation function ensures lights don't affect geometry outside the maximum light radius
fn rangeAttenuation(distance: f32) -> f32 {
    return clamp(1.f - pow(distance / ${lightRadius}, 4.f), 0.f, 1.f) / (distance * distance);
}

fn calculateLightContrib(light: Light, posWorld: vec3f, nor: vec3f) -> vec3f {
    let vecToLight = light.pos - posWorld;
    let distToLight = length(vecToLight);

    let lambert = max(dot(nor, normalize(vecToLight)), 0.f);
    return light.color * lambert * rangeAttenuation(distToLight);
}

fn calculateClusterPos(position: vec3f, camera: ptr<uniform, CameraUniforms>, numClusters: vec3u) -> vec3u {
    let clipPlaneRatio = camera.clipPlanes[1] / camera.clipPlanes[0];

    // Get position in view space
    let posView = camera.viewMat * vec4f(position, 1);
    
    // Get x- and y-coordinate in NDC space
    let posClip = camera.viewProjMat  * vec4f(position, 1);
    let xyNDC = posClip.xy / posClip.w;

    // Get cluster position from calculated coordinates
    return vec3u(
        u32(0.5 * (xyNDC.x + 1) * f32(numClusters.x)),
        u32(0.5 * (xyNDC.y + 1) * f32(numClusters.y)),
        // Get z-slice from z-coordinate in view space (negative z!)
        u32(f32(numClusters.z) * log(- posView.z / camera.clipPlanes[0]) / log(clipPlaneRatio))
    );
}

fn calculateClusterIdx(clusterIdx: vec3u, numClusters: vec3u) -> u32 {
    return clusterIdx.x +
           clusterIdx.y * numClusters.x +
           clusterIdx.z * numClusters.x * numClusters.y;
}