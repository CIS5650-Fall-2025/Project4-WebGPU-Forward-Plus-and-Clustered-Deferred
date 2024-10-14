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
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;

// debug depth min max
@group(${bindGroup_scene}) @binding(2) var<storage> tilesMinBuffer: array<f32>;
@group(${bindGroup_scene}) @binding(3) var<storage> tilesMaxBuffer: array<f32>;
@group(${bindGroup_scene}) @binding(4) var<uniform> res: Resolution;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

struct FragmentInput
{
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

struct Resolution {
    width: u32,
    height: u32
};

@fragment
fn main(in: FragmentInput, @builtin(position) fragCoord: vec4<f32>) -> @location(0) vec4f
{
    let tileX = u32(fragCoord.x / 16.0);
    let tileY = u32(fragCoord.y / 16.0);
    let numTilesX = u32(ceil(f32(res.width) / 16.0));
    let tileIndex = tileY * numTilesX + tileX;
    let minDepth = tilesMinBuffer[tileIndex];
    let maxDepth = tilesMaxBuffer[tileIndex];
    return vec4(vec3(maxDepth), 1.0);

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
}
