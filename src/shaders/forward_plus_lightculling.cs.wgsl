struct Resolution {
    width: u32,
    height: u32
};

@group(0) @binding(0) var<uniform> res: Resolution;
@group(0) @binding(1) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(2) var<storage> lightSet: LightSet;
@group(0) @binding(3) var<storage, read_write> tilesLightBuffer: array<u32>;
@group(0) @binding(4) var<storage, read_write> tilesLightGridBuffer: array<u32>;

// const INFINITE: f32 = 3.40282346638528859812e+38f;
// const tileSize: f32 = 128.0;
// const invTileZSize: f32 = 0.1;
// const maxLightPerTile: u32 = 100;

@compute @workgroup_size(8, 8, 1)
fn computeMain(@builtin(global_invocation_id) global_id: vec3u,
    @builtin(local_invocation_id) local_id: vec3u,
    @builtin(workgroup_id) workgroup_id: vec3u,
    @builtin(num_workgroups) numTiles: vec3u) 
{
    var tileIndex = global_id.z * numTiles.x * numTiles.y * 64 + global_id.y * numTiles.x * 8 + global_id.x;
    // compute bounding box
    var aabbMin: vec3f = vec3f(INFINITE, INFINITE, INFINITE);
    var aabbMax: vec3f = vec3f(-INFINITE, -INFINITE, -INFINITE);

    var tileXmin_screen = f32(global_id.x) * (tileSize);
    var tileYmin_screen = f32(global_id.y) * (tileSize);
    var tileXmax_screen = min(tileXmin_screen + tileSize, f32(res.width));
    var tileYmax_screen = min(tileYmin_screen + tileSize, f32(res.height));

    var tileXmin_clip = (tileXmin_screen / f32(res.width)) * 2.0 - 1.0;
    var tileYmin_clip = 1.0 - (tileYmin_screen / f32(res.height)) * 2.0;
    var tileXmax_clip = (tileXmax_screen / f32(res.width)) * 2.0 - 1.0;
    var tileYmax_clip = 1.0 - (tileYmax_screen / f32(res.height)) * 2.0;

    var tileZmin_clip = f32(global_id.z) * invTileZSize;
    var tileZmax_clip = min(tileZmin_clip + invTileZSize, 1.0);

    var points: array<vec3f, 8>;
    points[0] = vec3f(tileXmin_clip, tileYmin_clip, tileZmin_clip);
    points[1] = vec3f(tileXmax_clip, tileYmin_clip, tileZmin_clip);
    points[2] = vec3f(tileXmax_clip, tileYmax_clip, tileZmin_clip);
    points[3] = vec3f(tileXmin_clip, tileYmax_clip, tileZmin_clip);
    points[4] = vec3f(tileXmin_clip, tileYmin_clip, tileZmax_clip);
    points[5] = vec3f(tileXmax_clip, tileYmin_clip, tileZmax_clip);
    points[6] = vec3f(tileXmax_clip, tileYmax_clip, tileZmax_clip);
    points[7] = vec3f(tileXmin_clip, tileYmax_clip, tileZmax_clip);
   

    // transform each point of view frustum cluster to world space
    for (var i = 0u; i < 8u; i = i + 1u) {
        let worldPos = cameraUniforms.invViewProj * vec4<f32>(points[i], 1.0);
        aabbMin = min(aabbMin, worldPos.xyz);
        aabbMax = max(aabbMax, worldPos.xyz);
    }

    // traverse lights
    var lightCount = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];
        if (calculateLightIntersection(light, aabbMin, aabbMax)) {
            tilesLightBuffer[tileIndex] = lightIdx;
            lightCount = lightCount + 1u;
        }
    }
    tilesLightGridBuffer[tileIndex] = lightCount;

}
