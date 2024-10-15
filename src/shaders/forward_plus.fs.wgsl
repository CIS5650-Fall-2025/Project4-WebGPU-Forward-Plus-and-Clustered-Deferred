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
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

// Fragment Inputs
struct FragmentInput {
    @builtin(position) fragCoord: vec4f,
    @location(0) fragPosition: vec3f,
    @location(1) normal: vec3f,
    @location(2) diffuseColor: vec3f,
};

// Fragment Output
struct FragmentOutput {
    @location(0) color: vec4f,
};

fn getClusterIndex(fragPos: vec3f) -> u32 {

}

fn calculateLightContribution(light: Light, fragPos: vec3f, normal: vec3f) -> vec3f {

}

@fragment
fn main(input: FragmentInput) -> FragmentOutput {
    let fragPos = input.fragPosition;
    let normal = normalize(input.normal);
    let diffuseColor = input.diffuseColor;
    let clusterIndex = getClusterIndex(fragPos);
    // !debug the clusterSet in common.wgsl
    let numLights = clusterSet.numLights[clusterIndex];
    // accumulate light contributions
    var accumulatedLight = vec3f(0.0);
    for (var i: u32 = 0; i < numLights; ++i) {
        let lightIndex = clusterSet.lightIndices[clusterIndex * 100 + i]; // max 100 light per cluster
        let light = lightSet.lights[lightIndex];
        accumulatedLight += calculateLightContribution(light, fragPos, normal);
    }
    // multiply the diffuse color
    let finalColor = diffuseColor * accumulatedLight;
    return FragmentOutput(vec4f(finalColor, 1.0));
}