// ─────────────────────────────────────────────────────────────
// Vertex Shader: Fullscreen Quad
//   • Generates 2 triangles covering the entire screen
//   • Outputs clip-space position and UV coordinates
// ─────────────────────────────────────────────────────────────

// Vertex output struct
struct VertexOut {
    @builtin(position) clipPosition: vec4f,  // Clip-space position
    @location(0) uv: vec2f   // Texture coordinates
};


@vertex
fn main(@builtin(vertex_index) vertexIndex: u32) -> VertexOut {
    // Fullscreen quad in clip-space
    let clipPositions = array<vec2f, 6>(
        vec2f(-1.0,  1.0),
        vec2f(-1.0, -1.0),
        vec2f( 1.0, -1.0),
        vec2f( 1.0, -1.0),
        vec2f( 1.0,  1.0),
        vec2f(-1.0,  1.0),
    );

    let pos = clipPositions[vertexIndex];

    var output: VertexOut;

    output.clipPosition = vec4f(pos, 0.0, 1.0);       // Set clip-space position
    output.uv = pos * 0.5 + vec2f(0.5, 0.5);          // Convert from [-1, 1] to [0, 1]
    output.uv.y = 1.0 - output.uv.y;                  // Flip Y for texture coordinates

    return output;
}
