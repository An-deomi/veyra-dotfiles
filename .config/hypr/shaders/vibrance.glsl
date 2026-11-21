#version 300 es
precision highp float;
in vec2 v_texcoord;
uniform sampler2D tex;
out vec4 fragColor;

void main() {
    vec4 pix = texture(tex, v_texcoord);
    float luma = dot(pix.rgb, vec3(0.2126, 0.7152, 0.0722));
    float maxC = max(pix.r, max(pix.g, pix.b));
    float minC = min(pix.r, min(pix.g, pix.b));
    float sat = maxC - minC;
    float boost = 0.24 * (1.0 - sat);
    vec3 col = mix(vec3(luma), pix.rgb, 1.0 + boost);
    fragColor = vec4(clamp(col, 0.0, 1.0), pix.a);
}
