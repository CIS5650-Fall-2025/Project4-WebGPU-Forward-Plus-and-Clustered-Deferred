// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights

// ------------------------------------
// Shading process:
// ------------------------------------
// Determine which cluster contains the current fragment.
// Retrieve the number of lights that affect the current fragment from the cluster’s data.
// Initialize a variable to accumulate the total light contribution for the fragment.
// For each light in the cluster:
//     Access the light's properties using its index.
//     Calculate the contribution of the light based on its position, the fragment’s position, and the surface normal.
//     Add the calculated contribution to the total light accumulation.
// Multiply the fragment’s diffuse color by the accumulated light contribution.
// Return the final color, ensuring that the alpha component is set appropriately (typically to 1).
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;

@group(${bindGroup_cluster}) @binding(0) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

const NUM_CLUSTERS_X: u32 = 16;
const NUM_CLUSTERS_Y: u32 = 9;
const NUM_CLUSTERS_Z: u32 = 24;

// Fragment Inputs
struct FragmentInput {
    @builtin(position) fragCoord: vec4f,
    @location(0) fragPosition: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f,
};

// Fragment Output
struct FragmentOutput {
    @location(0) color: vec4f,
};

fn getClusterIndex(fragPos: vec3f) -> u32 {
    let screenPos = cameraUniforms.viewProjMat * vec4f(fragPos, 1.0);
    // convert fragPos to normalized device coord
    let ndcPos = screenPos.xyz / screenPos.w;
    // Map NDC (-1 to 1) to screen coordinates (0 to 1)
    let screenX = (ndcPos.x * 0.5 + 0.5) * cameraUniforms.screenSize.x;
    let screenY = (ndcPos.y * 0.5 + 0.5) * cameraUniforms.screenSize.y;
    // Cluster X and Y calculation
    let clusterX = u32(screenX * f32(NUM_CLUSTERS_X));
    let clusterY = u32(screenY * f32(NUM_CLUSTERS_Y));
    // Cluster Z calculation based on depth
    let fragDepth = -fragPos.z;
    let logDepth = log2(fragDepth / cameraUniforms.near) / log2(cameraUniforms.far / cameraUniforms.near);
    let clusterZ = u32(logDepth * f32(NUM_CLUSTERS_Z));
    // Ensure cluster indices are within bounds
    let clampedX = clamp(clusterX, 0u, NUM_CLUSTERS_X - 1);
    let clampedY = clamp(clusterY, 0u, NUM_CLUSTERS_Y - 1);
    let clampedZ = clamp(clusterZ, 0u, NUM_CLUSTERS_Z - 1);
    // Compute the final cluster index
    return clampedZ * NUM_CLUSTERS_X * NUM_CLUSTERS_Y + clampedY * NUM_CLUSTERS_X + clampedX;
}

fn calculateLightContribution(light: Light, fragPos: vec3f, normal: vec3f) -> vec3f {
    let lightDir = normalize(light.pos - fragPos);
    let diffuse = max(dot(normal, lightDir), 0.0);
    return light.color * light.intensity * diffuse;
}

@fragment
fn main(input: FragmentInput) -> FragmentOutput {
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);


/*
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, input.uv);
    let clusterIndex = getClusterIndex(fragPos);

    // !debug the clusterSet in common.wgsl
    let numLights = clusterSet.numLights[clusterIndex];
    // accumulate light contributions
    var accumulatedLight = vec3f(0.0);
    for (var i: u32 = 0; i < numLights; ++i) {
        let lightIndex = clusterSet.lightIndices[clusterIndex * 100 + i]; // max 100 light per cluster
        let light = lightSet.lights[lightIndex];
        accumulatedLight += calculateLightContribution(light, input.pos, input.nor);
    }
    // multiply the diffuse color
    let finalColor = diffuseColor * accumulatedLight;
    return FragmentOutput(vec4f(finalColor, 1.0));
    */
} 
