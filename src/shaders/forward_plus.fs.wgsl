// TODO-2: implement the Forward+ fragment shader

// See naive.fs.wgsl for basic fragment shader setup; this shader should use light clusters instead of looping over all lights
@group(${bindGroup_scene}) @binding(0) var<uniform> cameraUniforms: CameraUniforms;
@group(${bindGroup_scene}) @binding(1) var<storage, read> lightSet: LightSet;
@group(${bindGroup_scene}) @binding(2) var<storage, read> clusterSet: ClusterSet;

@group(${bindGroup_material}) @binding(0) var diffuseTex: texture_2d<f32>;
@group(${bindGroup_material}) @binding(1) var diffuseTexSampler: sampler;

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

struct FragmentInput
{
    @builtin(position) fragCoord: vec4f,
    @location(0) pos: vec3f,
    @location(1) nor: vec3f,
    @location(2) uv: vec2f
}

@fragment
fn main(in: FragmentInput) -> @location(0) vec4f
{
    let diffuseColor = textureSample(diffuseTex, diffuseTexSampler, in.uv);
    if (diffuseColor.a < 0.5f) {
        discard;
    }

    var totalLightContrib = vec3f(0, 0, 0);

    var clipPos = cameraUniforms.viewProjMat * vec4f(in.pos, 1.0);

    var zTile = log(clipPos.z / cameraUniforms.zNear) / log(cameraUniforms.zFar / cameraUniforms.zNear);
    zTile = floor(zTile * cameraUniforms.tileCountZ);

    var tilePixelSize_X = cameraUniforms.canvasSizeX / cameraUniforms.tileCountX;
    var tilePixelSize_Y = f32(1368) / f32(cameraUniforms.tileCountY);

    var tileXYZ = vec3u(
        min(u32(cameraUniforms.tileCountX) - 1u, u32(in.fragCoord.x / f32(tilePixelSize_X) )),
        min(u32(cameraUniforms.tileCountY) - 1u, u32(in.fragCoord.y / f32(tilePixelSize_Y) )),
        min(u32(cameraUniforms.tileCountZ) - 1u, u32(zTile))
    );
    var tileIdx = tileXYZ.x + tileXYZ.y * u32(cameraUniforms.tileCountX) + tileXYZ.z * u32(cameraUniforms.tileCountX) * u32(cameraUniforms.tileCountY);

    // Retrieve the number of lights that affect the current fragment from the cluster’s data
    var numLights = clusterSet.clusters[tileIdx].lightCount; 

    // For each light in the cluster
    for (var lightIdx = 0u; lightIdx < numLights; lightIdx++) {
        let light = lightSet.lights[clusterSet.clusters[tileIdx].lightIndices[lightIdx]];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = vec3f(0.0, 0.0, 0.0);

    //finalColor = diffuseColor.rgb * totalLightContrib;


//  -------------    Debugging  ----------------
    // finalColor = vec3f(
    //     f32(tileXYZ.x) / f32(cameraUniforms.tileCountX - 1),
    //     f32(tileXYZ.y) / f32(cameraUniforms.tileCountY - 1),
    //     f32(tileXYZ.z) / f32(cameraUniforms.tileCountZ - 1)
    // );
    // hot map for debugging
    //finalColor = vec3f(f32(numLights) / 100, 0.0, 0.0);

 
    var tileIdx3D = vec3u(tileIdx % u32(cameraUniforms.tileCountX), (tileIdx / u32(cameraUniforms.tileCountX)) % u32(cameraUniforms.tileCountY), tileIdx / u32((cameraUniforms.tileCountX) * cameraUniforms.tileCountY));
    //finalColor = vec3f(f32(tileIdx3D.x) / f32(cameraUniforms.tileCountX), 0, 0);

    let colorOptions = array<vec3f, 8>(
        vec3f(1.0, 0.0, 0.0),  // Red
        vec3f(0.0, 1.0, 0.0),  // Green
        vec3f(0.0, 0.0, 1.0),  // Blue
        vec3f(1.0, 1.0, 0.0),  // Yellow
        vec3f(1.0, 0.0, 1.0),  // Magenta
        vec3f(0.0, 1.0, 1.0),  // Cyan
        vec3f(1.0, 1.0, 1.0),  // White
        vec3f(0.5, 0.5, 0.5)   // Grey
    );

    let colorIdx = u32(tileXYZ.x + tileXYZ.y + tileXYZ.z) % 8;

    //finalColor += colorOptions[colorIdx];
    finalColor = diffuseColor.rgb * totalLightContrib;

    if(numLights > 0) {
        //finalColor += vec3f(f32(numLights) / 100, 0.0, 0.0);
    }


    return vec4f(finalColor, 1);
}