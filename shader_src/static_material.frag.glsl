#version 450

layout(set = 0, binding = 1) uniform View {
    mat4 view;
    vec3 view_position;
};

layout(push_constant) uniform Model {
    mat4 model;
    mat3 inverse_normal;
    uint tex_indices;
};

layout(set = 0, binding = 2) uniform sampler sampler0;

layout(set = 1, binding = 0) uniform texture2D diffuse_map[256];
layout(set = 1, binding = 1) uniform texture2D specular_map[256];
layout(set = 1, binding = 2) uniform texture2D emissive_map[256];
layout(set = 1, binding = 3) uniform texture2D normal_map[256];

layout(location = 0) in vec3 position;
layout(location = 1) in vec3 normal;
layout(location = 2) in vec2 tex_coord;
layout(location = 3) in vec4 color;

layout(location = 0) out vec4 out_color;
layout(location = 1) out vec4 out_bloom;

struct DirectionalLight {
    vec3 direction;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct PointLight {
    vec3 position;

    float constant;
    float linear;
    float quadratic;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

struct SpotLight {
    vec3 position;
    vec3 direction;
    float cut_off;
    float outer_cut_off;

    float constant;
    float linear;
    float quadratic;

    vec3 ambient;
    vec3 diffuse;
    vec3 specular;
};

const float GAMMA = 2.2;

vec3 directional_light(DirectionalLight light, vec3 normal, vec3 view_direction, vec3 diffuse_sample, float specular_sample) {
    vec3 light_direction = normalize(-light.direction);
    // diffuse shading
    float diff = max(dot(normal, light_direction), 0.0);
    // specular shading (blinn-phong)
    vec3 halfway_dir = normalize(light_direction + view_direction);
    float spec = pow(max(dot(normal, halfway_dir), 0.0), 16.0);
    // combine results
    vec3 ambient = light.ambient * diffuse_sample;
    vec3 diffuse = light.diffuse * diff * diffuse_sample;
    vec3 specular = light.specular * spec * specular_sample;
    return ambient + diffuse + specular;
}

vec3 point_light(PointLight light, vec3 normal, vec3 fragment_position, vec3 view_direction, vec3 diffuse_sample, float specular_sample) {
    vec3 light_direction = normalize(light.position - fragment_position);
    // diffuse shading
    float diff = max(dot(normal, light_direction), 0.0);
    // specular shading (blinn-phong)
    vec3 halfway_dir = normalize(light_direction + view_direction);
    float spec = pow(max(dot(normal, halfway_dir), 0.0), 16.0);
    // attenuation
    float distance = length(light.position - fragment_position);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));
    // combine results
    vec3 ambient = light.ambient * diffuse_sample;
    vec3 diffuse = light.diffuse * diff * diffuse_sample;
    vec3 specular = light.specular * spec * specular_sample;
    ambient *= attenuation;
    diffuse *= attenuation;
    specular *= attenuation;
    return ambient + diffuse + specular;
}

vec3 spot_light(SpotLight light, vec3 normal, vec3 fragment_position, vec3 view_direction, vec3 diffuse_sample, float specular_sample) {
    vec3 light_direction = normalize(light.position - fragment_position);
    // diffuse shading
    float diff = max(dot(normal, light_direction), 0.0);
    // specular shading (blinn-phong)
    vec3 halfway_dir = normalize(light_direction + view_direction);
    float spec = pow(max(dot(normal, halfway_dir), 0.0), 16.0);
    // attenuation
    float distance = length(light.position - fragment_position);
    float attenuation = 1.0 / (light.constant + light.linear * distance + light.quadratic * (distance * distance));
    // spotlight intensity
    float theta = dot(light_direction, normalize(-light.direction));
    float epsilon = light.cut_off - light.outer_cut_off;
    float intensity = clamp((theta - light.outer_cut_off) / epsilon, 0.0, 1.0);
    // combine results
    vec3 ambient = light.ambient * diffuse_sample;
    vec3 diffuse = light.diffuse * diff * diffuse_sample;
    vec3 specular = light.specular * spec * specular_sample;
    ambient *= attenuation * intensity;
    diffuse *= attenuation * intensity;
    specular *= attenuation * intensity;
    return ambient + diffuse + specular;
}

const DirectionalLight DIRECTIONAL_LIGHT = DirectionalLight(vec3(0.2, -1.0, 0.0), vec3(0.2), vec3(1.0), vec3(1.0));
const PointLight POINT_LIGHTS[4] = {
    PointLight(vec3(10.0, 10.0, 10.0), 1.0, 0.09, 0.032, vec3(0.2), vec3(1.0), vec3(1.0)),
    PointLight(vec3(-10.0, 10.0, -10.0), 1.0, 0.09, 0.032, vec3(0.2), vec3(1.0), vec3(1.0)),
    PointLight(vec3(10.0, -10.0, 0.0), 1.0, 0.09, 0.032, vec3(0.2), vec3(1.0), vec3(1.0)),
    PointLight(vec3(-10.0, -10.0, 0.0), 1.0, 0.09, 0.032, vec3(0.2), vec3(1.0), vec3(1.0)),
};

void main() {
    uint diffuse_index = tex_indices & 0x000000FF;
    uint specular_index = tex_indices & 0x0000FF00 >> 8;
    uint emissive_index = tex_indices & 0x00FF0000 >> 16;
    uint normal_index = tex_indices & 0xFF000000 >> 24;

    // gamma-corrected sampled diffuse
    vec3 diffuse_sample = pow(texture(sampler2D(diffuse_map[diffuse_index], sampler0), tex_coord).rgb * color.rgb, vec3(GAMMA));
    float specular_sample = texture(sampler2D(specular_map[specular_index], sampler0), tex_coord).r;
    float emissive_sample = texture(sampler2D(emissive_map[emissive_index], sampler0), tex_coord).r;
    // convert normal to [-1.0, 1.0]
    vec3 normal_sample = (texture(sampler2D(normal_map[normal_index], sampler0), tex_coord).rgb * vec3(2.0)) - vec3(1.0);

    // TODO: perterb normal
    vec3 norm = normalize(normal);
    vec3 view_direction = normalize(view_position - position);

    vec3 result = directional_light(DIRECTIONAL_LIGHT, norm, view_direction, diffuse_sample, specular_sample);
    for (int i = 0; i < 4; i++) {
        result += point_light(POINT_LIGHTS[i], norm, position, view_direction, diffuse_sample, specular_sample);
    }

    // Add emissive
    float distance = length(view_position - position);
    float emissive = 1000.0 * emissive_sample;
    emissive *= 1.0 / (distance * distance);
    result += emissive;

    out_color = vec4(result, color.a);

    // Compute the bloom
    float brightness = dot(result, vec3(0.2126, 0.7152, 0.0722));
    if(brightness > 1.0) {
        out_bloom = vec4(result, 1.0);
    } else {
        out_bloom = vec4(0.0, 0.0, 0.0, 1.0);
    }
}
