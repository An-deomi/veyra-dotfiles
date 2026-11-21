#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    float scan = 0.93 + 0.07 * sin(v_texcoord.y * 1080.0 * 3.14159);
    vec2 uv = v_texcoord * (1.0 - v_texcoord.yx);
    float vig = clamp(pow(uv.x * uv.y * 16.0, 0.18), 0.72, 1.0);
    vec3 col = clamp(pix.rgb * scan * vig, 0.0, 1.0);
    fragColor = vec4(col, pix.a);
}
