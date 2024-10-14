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
    viewProj: mat4x4<f32>
}

fn square(x: f32) -> f32 {
    return x * x;
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

fn calculateLightIntersection(light: Light, minb: vec3f, maxb: vec3f) -> bool {
    // calculate distance of light to the bounding box
    var lightDist = 0.0;
    for (var i = 0u; i < 3u; i = i + 1u) {
        if (light.pos[i] < maxb[i] && light.pos[i] > minb[i]) {
            continue;
        }
        lightDist += square(min(abs(light.pos[i] - maxb[i]), abs(light.pos[i] - minb[i])));
    }

    return lightDist < square(0.1); // assume light radius is 0.1 in ndc
}
