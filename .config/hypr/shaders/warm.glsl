#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    vec3 col = pix.rgb * vec3(1.0, 0.93, 0.80);
    fragColor = vec4(clamp(col, 0.0, 1.0), pix.a);
}
