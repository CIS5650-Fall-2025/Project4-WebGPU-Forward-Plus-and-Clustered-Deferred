// DONE-3: implement the Clustered Deferred fullscreen fragment shader
// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

// Declare the variable for the camera
@group(0) @binding(0) var<uniform> camera: CameraProps;

// Declare the color texture and sampler
@group(0) @binding(1) var colorTexture: texture_2d<f32>;
@group(0) @binding(2) var colorTextureSampler: sampler;

// Declare the depth texture
@group(0) @binding(3) var depthTexture: texture_2d<f32>;

// Declare the lights
@group(0) @binding(4) var<storage, read> lights: LightSet;

// Declare the cluster grid
@group(1) @binding(0) var<uniform> clusterGrid: vec4<u32>;

// Declare the light indices
@group(1) @binding(3) var<storage, read_write> clusterSet: ClusterSet;

// Declare the FragmentInput structure
struct FragmentInput {
    @location(0) coordinate: vec2f // Texture coordinate of the fragment
};

// Fragment shader main function
@fragment fn main(data: FragmentInput) -> @location(0) vec4f {
    // Acquire the color from the texture
    var color = textureSample(
        colorTexture,
        colorTextureSampler,
        data.coordinate
    );

    // Extract the normal from the color
    let normal = vec3f(
        color.r,
        color.g,
        color.b
    );

    // Extract the color components (encode them back from RGBA)
    let a = color.a;
    let b = floor(a / (1000.0f * 1000.0f));
    let g = floor((a - b * 1000.0f * 1000.0f) / 1000.0f);
    let r = (a - g * 1000.0f - b * 1000.0f * 1000.0f);
    color = vec4f(vec3f(r, g, b) / 1000.0f, 1.0f);

    // Extract depth information from the depth texture
    var depthR = textureSample(
        depthTexture,
        colorTextureSampler,
        data.coordinate
    ).r;

    // Compute the pixel coordinate in NDC (Normalized Device Coordinates)
    var pixelCoordinate = vec4f(
        data.coordinate.x * 2.0f - 1.0f,
        (1.0f - data.coordinate.y) * 2.0f - 1.0f,
        depthR,
        1.0f
    );

    // Compute the view space position using the inverse projection matrix
    var viewSpacePosition = camera.inverseProjMat * pixelCoordinate;

    // Perform perspective divide
    viewSpacePosition /= viewSpacePosition.w;

    // Compute the world space position using the inverse view matrix
    var worldSpacePosition = camera.inverseViewMat * vec4f(viewSpacePosition.xyz, 1.0f);

    // Project the fragment position into clip space
    let position = camera.viewProjMat * vec4f(worldSpacePosition.xyz, 1.0f);

    // Compute the pixel-space coordinate
    let coordinate = position.xy / position.w;

    // Compute the linear depth value
    let depth = log(position.z / camera.camera.x) / log(camera.camera.y / camera.camera.x);

    // Compute the cluster index based on the 2D coordinate and depth
    let x = u32(floor((coordinate.x * 0.5f + 0.5f) * f32(clusterGrid.x)));
    let y = u32(floor((coordinate.y * 0.5f + 0.5f) * f32(clusterGrid.y)));
    let z = u32(floor(depth * f32(clusterGrid.z)));
    let index = x + y * clusterGrid.x + z * clusterGrid.x * clusterGrid.y;

    // Compute the start index for the lights in the cluster
    let startIndex = index * clusterGrid.w;

    // Declare the total light contribution variable
    var totalLightContribution = vec3f(0.0f, 0.0f, 0.0f);

    // Iterate through the lights in the cluster using a for loop
    for (var count = 0u; count < clusterGrid.w; count += 1) {
        // Get the current light index
        let lightIndex = clusterSet.lightIndices[startIndex + count];

        // Exit the loop if the light index is invalid (usually a sentinel value)
        if (lightIndex == ${invalidIndexValue}) {
            break;
        }

        // Retrieve the light based on its index
        let light = lights.lights[lightIndex];

        // Update the total light contribution using a helper function
        totalLightContribution += calculateLightContrib(light, worldSpacePosition.xyz, normal);
    }

    // Update the color with the light contribution
    color = vec4f(color.rgb * totalLightContribution, 1.0f);

    // Return the final fragment color
    return vec4f(color.rgb, 1.0f);
}
