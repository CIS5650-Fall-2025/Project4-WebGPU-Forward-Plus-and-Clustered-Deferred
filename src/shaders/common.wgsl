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
struct ClusterSet {
    light_indices: array<u32>
}

struct CameraUniforms {
    // TODO-1.3: add an entry for the view proj mat (of type mat4x4f)
    viewProj: mat4x4f,
    near_plane: f32,
    far_plane: f32
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

fn prod(vector: vec3u) -> u32 {
    return vector.x * vector.y * vector.z;
}

fn compute_cluster_index(position: vec3f, camera_uniforms: CameraUniforms, cluster_grid_dimensions: vec3u) -> vec3u {
    let clip_space_coordinates = camera_uniforms.viewProj * vec4(position, 1.0f);
    let normalized_screen_space = clip_space_coordinates.xy / clip_space_coordinates.w * 0.5f + 0.5f;
    let normalized_depth = log(clip_space_coordinates.z / camera_uniforms.near_plane) / log(camera_uniforms.far_plane / camera_uniforms.near_plane); 
    return vec3u(floor(clamp(vec3f(normalized_screen_space.x, normalized_screen_space.y, normalized_depth), vec3f(0.0f), vec3f(1.0f)) * vec3f(cluster_grid_dimensions)));
}

fn flatten_index(index: vec3u, grid_dimensions: vec3u) -> u32 {
    return index.x + index.y * grid_dimensions.x + index.z * grid_dimensions.x * grid_dimensions.y;
}

fn unflatten_index(index: u32, grid_dimensions: vec3u) -> vec3u {
    return vec3u(
        index % grid_dimensions.x,
        (index / grid_dimensions.x) % grid_dimensions.y,
        (index / (grid_dimensions.x * grid_dimensions.y))
    );
}
