@group(0) @binding(0) var<uniform> res: Resolution;
@group(0) @binding(1) var<uniform> cameraUniforms: CameraUniforms;
@group(0) @binding(2) var<uniform> tileInfo: TileInfo;
@group(0) @binding(3) var<storage, read_write> clusterBuffer: array<ClusterAABB>;

@compute @workgroup_size(${lightCullBlockSize}, ${lightCullBlockSize}, 1)
fn computeMain(@builtin(global_invocation_id) global_id: vec3u,
    @builtin(local_invocation_id) local_id: vec3u,
    @builtin(workgroup_id) workgroup_id: vec3u,
    @builtin(num_workgroups) numTiles: vec3u) 
{
    // compute bounding box
    var tileXmin_screen = f32(global_id.x) * (${tileSize});
    var tileYmin_screen = f32(global_id.y) * (${tileSize});

    if (tileXmin_screen >= f32(res.width) || tileYmin_screen >= f32(res.height))
    {
        return;
    }
    var tileXmax_screen = min(tileXmin_screen + ${tileSize}, f32(res.width));
    var tileYmax_screen = min(tileYmin_screen + ${tileSize}, f32(res.height));

    var tileXmin_clip = (tileXmin_screen / f32(res.width)) * 2.0 - 1.0;
    var tileYmin_clip = 1.0 - (tileYmin_screen / f32(res.height)) * 2.0;
    var tileXmax_clip = (tileXmax_screen / f32(res.width)) * 2.0 - 1.0;
    var tileYmax_clip = 1.0 - (tileYmax_screen / f32(res.height)) * 2.0;

    // clip space
    var tileMin = vec3f(tileXmin_clip, tileYmin_clip, 0.0); 
    var tileMax = vec3f(tileXmax_clip, tileYmax_clip, 1.0);

    // view space
    tileMin = clipToView(vec4(tileMin, 1.0), cameraUniforms.invProj);
    tileMax = clipToView(vec4(tileMax, 1.0), cameraUniforms.invProj);

    // bounding box of the tile frustum
    var tileMinNear = lineIntersectionToZPlane(tileMin, abs(tileMin.z));
    var tileMaxNear = lineIntersectionToZPlane(tileMax, abs(tileMin.z));
    var tileMinFar = lineIntersectionToZPlane(tileMin, abs(tileMax.z));
    var tileMaxFar = lineIntersectionToZPlane(tileMax, abs(tileMax.z));


    for (var depth: u32 = 0; depth < ${tileSizeZ}; depth += 1)
    {
        var clusterIdx = depth * tileInfo.numTilesX * tileInfo.numTilesY + global_id.y * tileInfo.numTilesX + global_id.x;
        var clusterMinNear = lerp(tileMinNear, tileMaxNear, f32(depth) / f32(${tileSizeZ}));
        var clusterMaxNear = lerp(tileMinNear, tileMaxNear, f32(depth + 1) / f32(${tileSizeZ}));
        var clusterMinFar = lerp(tileMinFar, tileMaxFar, f32(depth) / f32(${tileSizeZ}));
        var clusterMaxFar = lerp(tileMinFar, tileMaxFar, f32(depth + 1) / f32(${tileSizeZ}));

        clusterBuffer[clusterIdx].min = min(clusterMinNear, clusterMinFar);
        clusterBuffer[clusterIdx].max = max(clusterMaxNear, clusterMaxFar);
    }
    

}


