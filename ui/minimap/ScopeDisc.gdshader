shader_type canvas_item;

// The scope's glass: everything the Minimap draws is kept to its disc. A clip_children
// mask did this once, but clipping is a canvas group of its own and can't nest inside
// the UI's glow group (it drew as a solid white disc).

uniform vec2 center;
uniform float inner;    // fully drawn inside this
uniform float outer;    // gone past this

varying vec2 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	COLOR.a *= 1.0 - smoothstep(inner, outer, distance(local, center));
}
