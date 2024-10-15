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
@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

@group(${bindGroup_lightcull}) @binding(0) var<uniform> res: Resolution;
@group(${bindGroup_lightcull}) @binding(1) var<storage> tilesLightIdxBuffer: array<u32>;
@group(${bindGroup_lightcull}) @binding(2) var<storage> tilesLightGridBuffer: array<u32>;


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

    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);
    // for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
    //     let light = lightSet.lights[lightIdx];
    //     totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    // }

    let numTilesX = u32(ceil(f32(res.width ) / tileSize));
    let numTilesY = u32(ceil(f32(res.height) / tileSize));
    let numTilesZ = 10;
    let tileXidx = u32(fragCoord.x / tileSize);
    let tileYidx = u32(fragCoord.y / tileSize);

    var lightCount = 0u;
    for (var z: u32 = 0; z < 10; z++) {
        let tileZidx = u32(z);
        let tileIdx = tileZidx * numTilesX * numTilesY + tileYidx * numTilesX + tileXidx;
        let startIdx = tileIdx * maxLightPerTile;
        let endIdx = startIdx + tilesLightGridBuffer[tileIdx];
        lightCount += endIdx - startIdx;
        for (var lightIdx = startIdx; lightIdx < endIdx; lightIdx++) {
            let light = lightSet.lights[tilesLightIdxBuffer[lightIdx]];
            totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
        }
    }

    // return vec4(vec3(f32(2)  / 10.0), 1.0);
    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);
}
