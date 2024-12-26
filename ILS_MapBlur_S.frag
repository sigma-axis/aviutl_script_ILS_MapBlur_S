/*
MIT License
Copyright (c) 2024 sigma-axis

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

https://mit-license.org/
*/

//
// VERSION: v1.00
//

////////////////////////////////
#version 460 core

in vec2 TexCoord;

layout(location = 0) out vec4 FragColor;

layout(binding = 0) uniform sampler2D tex_img;
layout(binding = 1) uniform sampler2D tex_map;
uniform mat2 remap;
uniform vec2 remap_v;
uniform vec2 center;
uniform float blue_factor;
uniform mat2 flow;
uniform vec2 ini_pos;
uniform ivec2 count;
uniform int ext_map;

bool out_of_range(vec2 v) { return v.x < 0 || v.x > 1 || v.y < 0 || v.y > 1; }
vec2 pick_map(vec2 uv)
{
	if (ext_map == 0 && out_of_range(uv)) return vec2(0.0);

	vec4 c = texture(tex_map, uv);
	return (c.rg - center) * c.a * (1 - blue_factor * (1 - c.b));
}
vec4 pick_color(vec2 uv)
{
	vec4 c = texture(tex_img, uv);
	c.rgb *= c.a;
	return c;
}

vec4 sum(vec2 start, int count, mat2 flow)
{
	vec4 c = pick_color(start);
	vec4 ret = c;
	vec2 uv = start;
	for(int i = count; i > 0; i--) {
		vec2 d = pick_map(remap * uv + remap_v);
		if (d == vec2(0.0)) {
			ret += i * c;
			break;
		}
		uv += flow * d;

		c = pick_color(uv);
		ret += c;
	}

	return ret;
}

void main()
{
	vec2 d0 = pick_map(remap * TexCoord + remap_v);
	if (d0 == vec2(0.0)) {
		FragColor = texture(tex_img, TexCoord);
		return;
	}
	d0 = flow * d0;

	vec4 color = sum(TexCoord - ini_pos.x * d0, count.x, -flow)
		+ sum(TexCoord + ini_pos.y * d0, count.y, +flow);

    color.rgb /= color.a;
    color.a /= count.x + count.y + 2;
    FragColor = color;
}
