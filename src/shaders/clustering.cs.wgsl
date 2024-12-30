// DONE-2: implement the light clustering compute shader

// ------------------------------------
// Calculating cluster bounds:
// ------------------------------------
// For each cluster (X, Y, Z):
//     - Calculate the screen-space bounds for this cluster in 2D (XY).
//     - Calculate the depth bounds for this cluster in Z (near and far planes).
//     - Convert these screen and depth bounds into view-space coordinates.
//     - Store the computed bounding box (AABB) for the cluster.

// ------------------------------------
// Assigning lights to clusters:
// ------------------------------------
// For each cluster:
//     - Initialize a counter for the number of lights in this cluster.

//     For each light:
//         - Check if the light intersects with the cluster’s bounding box (AABB).
//         - If it does, add the light to the cluster's light list.
//         - Stop adding lights if the maximum number of lights is reached.

//     - Store the number of lights assigned to this cluster.

// Declare the variable for the cluster grid
@group(0) @binding(0)
var<uniform> clusterGrid: vec4<u32>;

@group(0) @binding(1)
var<uniform> camera: CameraProps;

// Declare the variable for the lights
@group(0) @binding(2)
var<storage, read> lights: LightSet;

// Declare the variable for the light indices
@group(0) @binding(3)
var<storage, read_write> clusterSet: ClusterSet;

// Declare the function for converting a point to its cluster indices
fn convert(point: vec3f) -> vec3i {
    // Project the given point
    let position = camera.viewProjMat * vec4(point, 1.0f);

    // Compute the pixel-space coordinate
    var coordinate = position.xy;

    // Perform perspective divide
    if (position.w > 0.0f) {
        coordinate /= position.w;
    }

    // Compute the linear depth
    let depth = clamp(log(position.z / camera.camera.x) / log(camera.camera.y / camera.camera.x), 0.0f, 1.0f);

    // Compute the cluster's x index
    let x = i32(floor((coordinate.x * 0.5f + 0.5f) * f32(clusterGrid.x)));

    // Compute the cluster's y index
    let y = i32(floor((coordinate.y * 0.5f + 0.5f) * f32(clusterGrid.y)));

    // Compute the cluster's z index
    let z = i32(floor(depth * f32(clusterGrid.z)));

    // Return the cluster indices
    return vec3i(x, y, z);
}

// Define corner signs outside the loop (since they do not change)
var<private> cornerSigns = array<vec3i, 8>(
    vec3i(-1, -1, -1),
    vec3i( 1, -1, -1),
    vec3i(-1,  1, -1),
    vec3i( 1,  1, -1),
    vec3i(-1, -1,  1),
    vec3i( 1, -1,  1),
    vec3i(-1,  1,  1),
    vec3i( 1,  1,  1)
);

// Compute shader
@compute @workgroup_size(${clusterWorkgroupSize}) fn main(@builtin(global_invocation_id) index: vec3u) {
    // Exit if the index is out of bounds
    if (index.x >= clusterGrid.x * clusterGrid.y * clusterGrid.z) {
        return;
    }

    // Acquire the x, y, z indices of the cluster
    let x = i32(index.x % clusterGrid.x);
    let y = i32((index.x / clusterGrid.x) % clusterGrid.y);
    let z = i32(index.x / (clusterGrid.x * clusterGrid.y));

    // Compute the start index for the lights in this cluster
    let startIndex = index.x * clusterGrid.w;

    // Declare the variable for the number of lights in this cluster
    var count = 0u;

    // Iterate through all the lights
    for (var lightIndex = 0u; lightIndex < lights.numLights; lightIndex += 1) {
        // Acquire the current light
        let light = lights.lights[lightIndex];

        // Initialize min and max indices
        var minIndex = convert(light.pos + vec3f(f32(cornerSigns[0].x) * ${lightRadius}, 
                                                  f32(cornerSigns[0].y) * ${lightRadius}, 
                                                  f32(cornerSigns[0].z) * ${lightRadius}));
        var maxIndex = minIndex;

        // Loop through the 8 corners of the bounding box
        for (var i = 0u; i < 8u; i = i + 1u) {
            let offset = vec3f(
                f32(cornerSigns[i].x) * ${lightRadius},
                f32(cornerSigns[i].y) * ${lightRadius},
                f32(cornerSigns[i].z) * ${lightRadius}
            );

            // Calculate the corner index
            let cornerIndex = convert(light.pos + offset);

            // Update min and max indices
            minIndex = min(minIndex, cornerIndex);
            maxIndex = max(maxIndex, cornerIndex);
        }

        // Skip this light if its bounding box is out of range
        if (minIndex.x > x || x > maxIndex.x ||
            minIndex.y > y || y > maxIndex.y ||
            minIndex.z > z || z > maxIndex.z) {
            continue;
        }

        // Write the light index
        clusterSet.lightIndices[startIndex + count] = lightIndex;

        // Increment the light count
        count += 1;

        // Exit if the count exceeds the cluster size
        if (count >= clusterGrid.w) {
            break;
        }
    }

    // Write the termination condition if fewer lights are found
    if (count < clusterGrid.w) {
        clusterSet.lightIndices[startIndex + count] = ${invalidIndexValue};
    }
}
