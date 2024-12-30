// DONE-3: implement the Clustered Deferred fullscreen vertex shader
// This shader should be very simple as it does not need all of the information passed by the the naive vertex shader.

// Declare the input structure for the fragment shader
struct FragmentInput {
    @builtin(position) point: vec4f, // Fragment position in clip space
    @location(0) coordinate: vec2f // Texture coordinate of the fragment
};

// Vertex shader main function
@vertex fn main(@builtin(vertex_index) index: u32) -> FragmentInput {
    // Create a constant array of positions for the fullscreen quad
    let positions = array<vec2f, 6>(
        vec2f(-1.0f, 1.0f),
        vec2f(-1.0f, -1.0f),
        vec2f(1.0f, -1.0f),
        vec2f(1.0f, -1.0f),
        vec2f(1.0f, 1.0f),
        vec2f(-1.0f, 1.0f)
    );

    // Declare the output data that will be passed to the fragment shader
    var data: FragmentInput;

    // Set the position of the vertex in clip space
    data.point = vec4f(
        positions[index].x,
        positions[index].y,
        0.0f, 1.0f
    );

    // Compute the texture coordinate
    data.coordinate = positions[index] * 0.5f + 0.5f;
    data.coordinate.y = 1.0f - data.coordinate.y; // Invert the Y coordinate for correct orientation

    // Return the data to the fragment shader
    return data;
}
