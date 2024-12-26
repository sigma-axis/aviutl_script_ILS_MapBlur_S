--[[
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
]]

--
-- VERSION: v1.00
--

--------------------------------

local ils = require "InlineScene_S";
local GLShaderKit = require "GLShaderKit";

local obj, math, tonumber = obj, math, tonumber;

local function error_mod(message)
	message = "InlineScene_S.lua: "..message;
	debug_print(message);
	local function err_mes()
		obj.setfont("MS UI Gothic", 42, 3);
		obj.load("text", message);
	end
	return setmetatable({}, { __index = function(...) return err_mes end });
end
if not GLShaderKit.isInitialized() then return error_mod [=[このデバイスでは GLShaderKit が利用できません!]=];
else
	local function lexical_comp(a, b, ...)
		return a == nil and 0 or a < b and -1 or a > b and 1 or lexical_comp(...);
	end
	local version = GLShaderKit.version();
	local v1, v2, v3 = version:match("^(%d+)%.(%d+)%.(%d+)$");
	v1, v2, v3 = tonumber(v1), tonumber(v2), tonumber(v3);
	-- version must be at least v0.4.0.
	if not (v1 and v2 and v3) or lexical_comp(v1, 0, v2, 4, v3, 0) < 0 then
		debug_print([=[現在の GLShaderKit のバージョン: ]=]..version);
		return error_mod [=[この GLShaderKit のバージョンでは動作しません!]=];
	end
end

-- ref: https://github.com/Mr-Ojii/AviUtl-RotBlur_M-Script/blob/main/script/RotBlur_M.lua
local function script_path()
    return debug.getinfo(1).source:match("@?(.*[/\\])");
end
local shader_path = script_path().."ILS_MapBlur_S.frag";

local center_def = 128;
local settings = {
	x = 0.0,
	y = 0.0,
	angle = 0.0,
	sync_angle = true,
	size = -1,
	scale = -1,
	center_r = center_def / 255,
	center_g = center_def / 255,
	side_b = 0.0,
	blur = 0,
};
local function settings_common(x, y, angle, sync_angle)
	settings.x = tonumber(x) or 0;
	settings.y = tonumber(y) or 0;
	settings.angle = tonumber(angle) or 0;
	settings.sync_angle = sync_angle ~= false;
end
---マップの配置情報を記録する．拡大率指定のタイプ．
---@param x number? 中央の点の X 座標．ピクセル単位で，既定値は `0`.
---@param y number? 中央の点の Y 座標．ピクセル単位で，既定値は `0`.
---@param angle number? 回転角度を指定．ラジアン単位で時計回りに正．既定値は `0`.
---@param sync_angle boolean? `angle` による回転をマップ指定の方向に加算するかどうかを指定．既定値は `true`.
---@param scale number? マップの拡大率を指定，既定値は等倍で `1.0`.
local function settings_byscale(x, y, angle, sync_angle, scale)
	settings_common(x, y, angle, sync_angle);
	settings.size = -1;
	settings.scale = math.max(tonumber(scale) or 1.0, 0);
end
---マップの配置情報を記録する．サイズ指定のタイプ．
---@param x number? 中央の点の X 座標．ピクセル単位で，既定値は `0`.
---@param y number? 中央の点の Y 座標．ピクセル単位で，既定値は `0`.
---@param angle number? 回転角度を指定．ラジアン単位で時計回りに正．既定値は `0`.
---@param sync_angle boolean? `angle` による回転をマップ指定の方向に加算するかどうかを指定．既定値は `true`.
---@param size number? マップのサイズを長辺の長さでピクセル単位で指定．`nil` だと 等倍指定と同等の効果．
local function settings_bysize(x, y, angle, sync_angle, size)
	local sz = tonumber(size);
	if sz then
		settings_common(x, y, angle, sync_angle);
		settings.size = math.max(sz, 0);
		settings.scale = -1;
	else settings_byscale(x, y, angle, sync_angle, 1.0) end
end
---マップ画像の基準色（「無風」を表す色）の指定と，青成分の直交方向への寄与量を記録する．
---@param r number? 赤成分の基準値．X 軸方向に寄与する．基本的には `0` から `255` の値，既定値は `128.0`.
---@param g number? 緑成分の基準値．Y 軸方向に寄与する．基本的には `0` から `255` の値，既定値は `128.0`.
---@param b number? 青成分の直交方向への寄与量. `0.0` から `1.0` の値，既定値は `0.0`.
---@param blur number? マップ画像に付与するぼかし量，既定値は `0`.
local function settings_color(r, g, b, blur)
	settings.center_r = (tonumber(r) or center_def) / 255;
	settings.center_g = (tonumber(g) or center_def) / 255;
	settings.side_b = tonumber(b) or 0;
	settings.blur = math.floor(0.5 + (tonumber(blur) or 0));
end
---記録した設定をリセットする．
---@param placement boolean `true` だと `_byscale` と `_bysize` での指定をリセット，`false` だと `_center` をリセット．
local function settings_reset(placement)
	if placement then
		settings_common(nil, nil, nil);
		settings.size = -1; settings.scale = -1;
	else settings_color(nil, nil, nil, nil) end
end

---マップぼかしを適用する．計算中に tempbuffer を上書きするため，必要ならデータの退避をしておくこと．
---@param name string マップに利用する "inline scene" の名前．(赤: X 軸方向，緑: Y 軸方向)
---@param flow number マップの順方向へのぼかし幅．
---@param side number マップと直交する方向へのぼかし幅．
---@param angle number マップでの色から方向を決定する際のずれ角度．ラジアン単位で時計回りに正．
---@param rel_pos number 順方向へのぼかしが起点から広がる方向．`-1.0` から `+1.0` で指定．
---@param keep_size boolean `false` だとぼかしの影響範囲の想定最大まで画像サイズを広げる．`true` だとそのまま．
---@param ext_map boolean マップ画像の外側を，最近辺で埋めるかどうかを指定．`false`: 外側は完全透明, `true`: 最近辺と同値．
---@param quality integer `(平均計算に使うピクセル数) - 1`. 最小値は `1`.
---@param curr_frame boolean? 現在フレームで合成された "inline scene" のみを対象にするかどうかを指定．既定値は `false`.
---@param recall_settings boolean? `settings_byscale` などで指定された設定を有効化する．`false` の場合はマップを拡縮して画像の幅高さに合わせる．
---@param reload boolean? GLShaderKit に対してシェーダーファイルの再読み込みを促す．デバッグ用．
local function apply(name, flow, side, angle, rel_pos, keep_size, ext_map, quality, curr_frame, recall_settings, reload)
	if flow == 0 and side <= 0 then return end

	local margin = 0;
	if not keep_size then
		margin = math.ceil((flow ^ 2 + 0.25 * side ^ 2) ^ 0.5);
		obj.effect("領域拡張", "上", margin, "下", margin, "左", margin, "右", margin);
	end

	-- get info about the cache.
	local cache_name, metrics, age = ils.read_cache(name);
	if not age or (curr_frame and age ~= "new") or metrics.alpha <= 0 then return end
	local W, H = metrics.w, metrics.h; -- size of the map, may inflate due to blurs.
	flow = flow * metrics.alpha; side = side * metrics.alpha;
	local work, w, h = obj.getpixeldata("work");

	local center_r, center_g, side_b, blur, remap, remap_x, remap_y =
		center_def / 255, center_def / 255, 0.0, 0,
		{ w / (w - 2 * margin), 0, 0, h / (h - 2 * margin) }, -margin / (w - 2 * margin), -margin / (h - 2 * margin);
	if recall_settings then
		center_r, center_g, side_b, blur = settings.center_r, settings.center_g, settings.side_b, settings.blur;

		if settings.size >= 0 or settings.scale >= 0 then
			-- construct the mapping of coordinates from the obj to the "inline scene".
			local rz = settings.angle + math.pi / 180 * metrics.rz;
			local C, S = math.cos(rz), math.sin(rz);
			local W1, H1 = math.min(1 - metrics.aspect, 1) * W, math.min(1 + metrics.aspect, 1) * H;
			local scale;
			if settings.scale < 0 then scale = settings.size / math.max(W1, H1);
			else scale = settings.scale * metrics.zoom end
			if scale <= 0 then return end -- all pixels are considered "flowless".
			if not ext_map then
				-- take blur into account.
				W, H = W + 2 * blur, H + 2 * blur;
				W1, H1 = math.min(1 - metrics.aspect, 1) * W, math.min(1 + metrics.aspect, 1) * H;
			end

			-- determine the matrix.
			remap[1] = w / (scale * W1) * C; remap[3] = h / (scale * W1) * S;
			remap[2] = w / (scale * H1) *-S; remap[4] = h / (scale * H1) * C;

			-- calculate the center.
			local cx, cy, base_cx, base_cy = obj.cx, obj.cy, obj.getvalue("cx"), obj.getvalue("cy");
			remap_x = settings.x - obj.ox + cx - base_cx;
			remap_y = settings.y - obj.oy + cy - base_cy;
			if ils.offscreen_drawn() then
				-- when off-screen draw is applied, the center is a bit offset.
				remap_x, remap_y = remap_x + obj.x - base_cx, remap_y + obj.y - base_cy;
			end

			remap_x, remap_y = 0.5 + remap_x / w, 0.5 + remap_y / h;
			remap_x, remap_y =
				remap[1] * remap_x + remap[3] * remap_y,
				remap[2] * remap_x + remap[4] * remap_y;
			remap_x, remap_y = 0.5 + metrics.cx / W - remap_x, 0.5 + metrics.cy / H - remap_y;

			-- adjust the angle of the flow.
			if settings.sync_angle then angle = angle + rz end
		end
	end

	local c, s = math.cos(angle), math.sin(angle);

	-- prepare shader context.
	GLShaderKit.activate()
	GLShaderKit.setPlaneVertex(1);
	GLShaderKit.setShader(shader_path, reload);
	GLShaderKit.setMatrix("remap", "2x2", false, remap);
	GLShaderKit.setFloat("remap_v", remap_x, remap_y);
	GLShaderKit.setFloat("center", center_r, center_g);
	GLShaderKit.setInt("ext_map", ext_map and 1 or 0);

	-- send image buffer to gpu.
	local data = obj.getpixeldata();
	GLShaderKit.setTexture2D(0, data, w, h);
	obj.copybuffer("tmp", "obj");
	obj.copybuffer("obj", cache_name);
	if blur > 0 then
		obj.effect("ぼかし", "範囲", blur, "サイズ固定",
			((settings.size < 0 and settings.scale < 0) or ext_map) and 1 or 0);
	end
	data = obj.getpixeldata();
	GLShaderKit.setTexture2D(1, data, W, H);

	-- first pass.
	if flow ~= 0 then
		local d, q, qf = flow / quality, math.modf(quality * (1 - rel_pos) / 2);
		if q >= quality then q, qf = q - 1, qf + 1 end
		GLShaderKit.setMatrix("flow", "2x2", false, { d * c / w, d * s / h, -d * s / w, d * c / h });
		GLShaderKit.setFloat("ini_pos", 1 - qf, qf);
		GLShaderKit.setInt("count", quality - q - 1, q);
		GLShaderKit.setFloat("blue_factor", 0);

		GLShaderKit.draw("TRIANGLES", work, w, h);
	end

	-- second pass.
	if side > 0 then
		if flow ~= 0 then
			-- send image buffer to gpu again if it's second time.
			GLShaderKit.setTexture2D(0, work, w, h);
			GLShaderKit.setTexture2D(1, data, W,H);
		end

		local d, q, qf = side / quality, math.modf(quality / 2);
		GLShaderKit.setMatrix("flow", "2x2", false, { -d * s / w, d * c / h, -d * c / w, -d * s / h });
		GLShaderKit.setFloat("ini_pos", 1 - qf, qf);
		GLShaderKit.setInt("count", quality - q - 1, q);
		GLShaderKit.setFloat("blue_factor", side_b);

		GLShaderKit.draw("TRIANGLES", work, w, h);
	end

	GLShaderKit.deactivate();

	-- restore the calculated data.
	if w ~= W or h ~= H then obj.copybuffer("obj", "tmp") end
	obj.putpixeldata(work);
end

local function equals_any(x, y, ...)
	if y == nil then return false;
	elseif x == y then return true;
	else return equals_any(x, ...) end
end
---直前のフィルタ効果が同じファイルの指定のスクリプトであることを確認する関数．付属の `.anm` 専用の用途・目的．
---@param ... string アニメーション効果名を列挙．
---@return boolean
local function is_former_script(...)
	local s = obj.getoption("script_name", -1, true);
	if s then
		local t = obj.getoption("script_name"):match("@.+$");
		if #t < #s and s:sub(-#t) == t then
			return equals_any(s:sub(1, -#t - 1), ...);
		end
	end
	return false;
end

return {
	settings_byscale = settings_byscale,
	settings_bysize = settings_bysize,
	settings_color = settings_color,
	settings_reset = settings_reset,

	apply = apply,

	is_former_script = is_former_script,
};
