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
@group(0) @binding(4) var<storage> lightSet: LightSet;
@group(0) @binding(5) var<storage, read_write> tilesLightBuffer: array<u32>;
@group(0) @binding(6) var<storage, read_write> tilesLightGridBuffer: array<u32>;

const scalar: f32 = 1 << 24;
const maxLightPerTile: u32 = 100;

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
        depth = u32(scalar * textureLoad(depthTexture, pixelCoord, 0));
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

    if (isValid && local_id.x == 0 && local_id.y == 0) {
        // store back to buffer
        let tilesMin = atomicLoad(&localMin);
        let tilesMax = atomicLoad(&localMax);

        tilesMinBuffer[tileIndex] = f32(tilesMin) / scalar;
        tilesMaxBuffer[tileIndex] = f32(tilesMax) / scalar;

        tilesMinBuffer[tileIndex] = textureLoad(depthTexture, pixelCoord, 0);
        tilesMaxBuffer[tileIndex] = f32(workgroup_id.x) / f32(numTilesX);
    }

    workgroupBarrier();

    // light culling
    var lightCount = 0u;
    for (var lightIdx = 0u; lightIdx < lightSet.numLights; lightIdx++) {
        let light = lightSet.lights[lightIdx];
        let minb = vec3f(tilesMinBuffer[tileIndex], tilesMinBuffer[tileIndex], tilesMinBuffer[tileIndex]);
        let maxb = vec3f(tilesMaxBuffer[tileIndex], tilesMaxBuffer[tileIndex], tilesMaxBuffer[tileIndex]);
        let isIntersect = calculateLightIntersection(light, minb, maxb);
        if (isIntersect) {
            tilesLightBuffer[tileIndex * maxLightPerTile + lightCount] = lightIdx;
            lightCount = lightCount + 1u;
        }
    }
    tilesLightGridBuffer[tileIndex * 2] = lightCount;
    tilesLightGridBuffer[tileIndex * 2 + 1] = tileIndex * maxLightPerTile;
}