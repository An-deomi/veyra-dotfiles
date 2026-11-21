#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    vec4 pix = texture(tex, v_texcoord);
    float noise = (hash(v_texcoord * vec2(1920.0, 1080.0)) - 0.5) * 0.035;
    vec2 uv = v_texcoord * (1.0 - v_texcoord.yx);
    float vig = clamp(pow(uv.x * uv.y * 16.0, 0.14), 0.78, 1.0);
    vec3 col = clamp((pix.rgb + noise) * vig, 0.0, 1.0);
    fragColor = vec4(col, pix.a);
}
