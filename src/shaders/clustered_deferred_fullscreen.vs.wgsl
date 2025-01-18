@vertex
fn main(@builtin(vertex_index) index: u32) -> @builtin(position) vec4f {
    // Vertices for triangle strip
    var vertices = array<vec2f, 4>(
        vec2f(-1.0, -1.0),
        vec2f( 1.0, -1.0),
        vec2f(-1.0,  1.0),
        vec2f( 1.0,  1.0)
    );

    return vec4f(vertices[index], 0.0, 1.0);
}