// TODO-3: implement the Clustered Deferred fullscreen fragment shader

// Similar to the Forward+ fragment shader, but with vertex information coming from the G-buffer instead.

@fragment
fn main(
  @builtin(position) coord : vec4f
) -> @location(0) vec4f {
  return vec4(1, 0, 0, 1);
}