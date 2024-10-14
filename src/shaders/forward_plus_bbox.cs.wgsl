struct Resolution {
    width: u32,
    height: u32
};

var<workgroup> localMin: atomic<u32>;
var<workgroup> localMax: atomic<u32>;

@group(0) @binding(0) var<uniform> res: Resolution;
@group(0) @binding(1) var<storage, read_write> tilesMinBuffer: array<f32>;
@group(0) @binding(2) var<storage, read_write> tilesMaxBuffer: array<f32>;
@group(0) @binding(3) var depthTexture: texture_depth_2d;

@compute @workgroup_size(16, 16, 1)
fn computeMain(@builtin(global_invocation_id) global_id: vec3u,
        @builtin(local_invocation_id) local_id: vec3u,
        @builtin(workgroup_id) workgroup_id: vec3u,
        @builtin(num_workgroups) numTiles: vec3u) {
    
    let isValid = global_id.x < res.width && global_id.y < res.height;

    let numTilesX = numTiles.x;
    let tileIndex = workgroup_id.y * numTilesX + workgroup_id.x;

    let pixelCoord = vec2<i32>(i32(global_id.x), i32(global_id.y));
 
    var depth: u32 = 0;
    if (isValid) {
        depth = u32((1 << 24) * textureLoad(depthTexture, pixelCoord, 0));
    }

    if (local_id.x == 0 && local_id.y == 0) {
        atomicStore(&localMin, depth);
        atomicStore(&localMax, depth);
    }

    workgroupBarrier();

    if (isValid)
    {
        atomicMin(&localMin, depth);
        atomicMax(&localMax, depth);
    }
    workgroupBarrier();

    if (local_id.x == 0 && local_id.y == 0) {
        // store back to buffer
        let tilesMin = atomicLoad(&localMin);
        let tilesMax = atomicLoad(&localMax);

        tilesMinBuffer[tileIndex] = f32(tilesMin) / f32((1 << 24));
        tilesMaxBuffer[tileIndex] = f32(tilesMax) / f32((1 << 24));
    }
}