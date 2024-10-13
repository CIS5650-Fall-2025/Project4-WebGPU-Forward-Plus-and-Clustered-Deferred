// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@group(${bindGroup_Gbuffer}) @binding(0) var defultSampler: sampler;
@group(${bindGroup_Gbuffer}) @binding(1) var positionBuffer: texture_storage_2d<rgba16float, write>;
@group(${bindGroup_Gbuffer}) @binding(2) var normalBuffer: texture_storage_2d<rgba16float, write>;
@group(${bindGroup_Gbuffer}) @binding(3) var albedoBuffer: texture_storage_2d<rgba16float, write>;
@group(${bindGroup_Gbuffer}) @binding(4) var depthTexture: texture_depth_2d;

fn linearDepth(depthSample : f32) -> f32 {
  return cameraUniforms.zFar*cameraUniforms.zNear / fma(depthSample, cameraUniforms.zNear-cameraUniforms.zFar, cameraUniforms.zFar);
}

fn getTile(fragCoord : vec4<f32>) -> vec3<u32> {
  // TODO: scale and bias calculation can be moved outside the shader to save cycles.
  let sliceScale = f32(tileCount.z) / log2(cameraUniforms.zFar / cameraUniforms.zNear);
  let sliceBias = -(f32(tileCount.z) * log2(cameraUniforms.zNear) / log2(cameraUniforms.zFar / cameraUniforms.zNear));
  let zTile = u32(max(log2(linearDepth(fragCoord.z)) * sliceScale + sliceBias, 0.0));

  return vec3<u32>(u32(fragCoord.x / (cameraUniforms.outputSize.x / f32(tileCount.x))),
                   u32(fragCoord.y / (cameraUniforms.outputSize.y / f32(tileCount.y))),
                   zTile);
}

fn getClusterIndex(fragCoord : vec4<f32>) -> u32 {
  let tile = getTile(fragCoord);
  return tile.x +
         tile.y * tileCount.x +
}

struct Fragmentin
{
    @builtin(position) fragPos: vec4f,
    @location(0) uv: vec2f,
}

const tileCount : vec3<u32> = vec3<u32>(32u, 18u, 48u);
@fragment
fn main(in: Fragmentin) -> @location(0) vec4f {
    let texCoords = in.uv;
    let depth = textureSample(depthTexture, defultSampler, in.uv);
    let screenPos = vec4<f32>(in.fragPos.xy, depth, 1.0);

    var totalLightContrib = vec3f(0, 0, 0);
    let clusterIndex = getClusterIndex(in.fragPos);
    let lightOffset  = clusterLights.lights[clusterIndex].offset;
    let lightCount   = clusterLights.lights[clusterIndex].count;

    for (var lightIndex = 0u; lightIndex < lightCount; lightIndex = lightIndex + 1u) {
        let i = clusterLights.indices[lightOffset + lightIndex];
        let light = lightSet.lights[i];
        totalLightContrib += calculateLightContrib(light, in.pos, in.nor);
    }

    var finalColor = diffuseColor.rgb * totalLightContrib;
    return vec4(finalColor, 1);

    // var tile : vec3<u32> = getTile(in.fragPos);
    // return vec4<f32>(colorSet[tile.z % 9u], 1.0);
}