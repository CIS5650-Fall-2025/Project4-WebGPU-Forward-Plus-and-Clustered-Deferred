// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ─────────────────────────────────────────────────────────────
// Forward+ Fragment Shader
//   • Uses clustered light list instead of brute-force loop
//   • Outputs lit color (no post-processing)
// ─────────────────────────────────────────────────────────────

// Scene-space resources
@group(${bindGroup_scene}) @binding(0) var<uniform>  camera      : CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet   : LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet : ClusterSet;

// Material resources
@group(${bindGroup_material}) @binding(0) var albedoTex  : texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var albedoSam  : sampler;

// Vertex-to-fragment payload
struct FSIn {
    @location(0) worldPos    : vec3<f32>,
    @location(1) worldNormal : vec3<f32>,
    @location(2) uv          : vec2<f32>,
};

// === Utility ===
fn attenuation(dist : f32) -> f32 {
    return clamp(1.0 - pow(dist / ${lightRadius}, 4.0), 0.0, 1.0) / (dist * dist);
}

fn lightContribution(l : Light, posW : vec3<f32>, n : vec3<f32>) -> vec3<f32> {
    let toLight  = l.pos - posW;
    let dist     = length(toLight);
    let lambert  = max(dot(n, normalize(toLight)), 0.0);
    return l.color * lambert * attenuation(dist);
}

// ─────────────────────────────────────────────────────────────
// Fragment entry
// ─────────────────────────────────────────────────────────────
@fragment
fn main(inFrag : FSIn) -> @location(0) vec4<f32> {
    // Alpha-tested albedo
    let albedo = textureSample(albedoTex, albedoSam, inFrag.uv);
    if (albedo.a < 0.5) { discard; }

    // ---------------------------------------------------------
    // 1. Determine cluster for this fragment
    // ---------------------------------------------------------
    //     • Screen-space tile   -> clusterX / clusterY
    //     • Log-depth slice     -> clusterZ
    // ---------------------------------------------------------
    let projPos = camera.viewProjMat * vec4<f32>(inFrag.worldPos, 1.0);
    let ndc     = projPos.xyz / projPos.w;
    let uv01    = ndc * 0.5 + 0.5;

    // Clamp to (0,1-ε) to avoid edge overflow
    let eps = 1e-4;
    let tileX = u32(clamp(uv01.x, 0.0, 1.0 - eps) * f32(clusterSet.numClustersX));
    let tileY = u32(clamp(uv01.y, 0.0, 1.0 - eps) * f32(clusterSet.numClustersY));

    // View-space Z for log slices
    let viewPos = (camera.viewMat * vec4<f32>(inFrag.worldPos, 1.0)).xyz;
    let viewZ   = -viewPos.z;
    let zNear   = camera.nearPlane;
    let zFar    = camera.farPlane;
    let logRatio = log(zFar / zNear);
    let sliceF  = clamp(log(viewZ / zNear) / logRatio * f32(clusterSet.numClustersZ),
                        0.0, f32(clusterSet.numClustersZ - 1u));
    let sliceZ  = u32(sliceF);

    // Flat cluster index
    let clusterIdx =
        tileX +
        tileY * clusterSet.numClustersX +
        sliceZ * clusterSet.numClustersX * clusterSet.numClustersY;

    let cluster   = clusterSet.clusters[clusterIdx];
    let lightCount = cluster.lightCount;

    // ---------------------------------------------------------
    // 2. Accumulate lighting from lights in this cluster
    // ---------------------------------------------------------
    var radiance = vec3<f32>(0.0);
    for (var i = 0u; i < lightCount; i++) {
        let lIdx  = cluster.lightIndices[i];
        let light = lightSet.lights[lIdx];
        radiance += lightContribution(light, inFrag.worldPos, inFrag.worldNormal);
    }

    // ---------------------------------------------------------
    // 3. Output final shaded color
    // ---------------------------------------------------------
    return vec4<f32>(albedo.rgb * radiance, 1.0);
}