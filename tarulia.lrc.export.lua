local tr = aegisub.gettext
---@diagnostic disable: lowercase-global --  Aegisub requires lowercase
script_name = tr"LRC/Export File (Dev)"
script_description = tr"Export Lyric File For Aegisub"
script_author = "ema"
script_version = "1"
---@diagnostic enable: lowercase-global

---Strip LRC-invalid characters (newlines) and ASS tags
---@param text string
---@return string
local function strip_tags(text)
	text = text:gsub('{[^}]+}', '')
	text = text:gsub('\\N', '')
	text = text:gsub('\\n', '')
	text = text:gsub('\\h', ' ')
	return text
end

---Insert UTF-8 BOM
---@return string
local function utf8_bom()
	return table.concat( {
		string.char(239, 187, 191), -- UTF8-BOM: EF BB BF
	} )
end

---Takes a time in ms and returns a timecode in mm:ss.ss
---Maxes out at 59:59.99
---TODO: re-add hours in minutes
---@param time_ms integer
---@return string
local function to_timecode(time_ms)
	local time_sec = time_ms / 1000
	local h = math.floor(time_sec / 3600)
	local m = math.floor(time_sec % 3600 / 60)
	local s = math.floor(time_sec % 60)
	local ms = math.floor( ((time_sec % 60) - math.floor(time_sec % 60)) * 100 )
	if h >= 1 then
		m = 59
		s = 59
		ms = 99
	end
	return string.format('%02d:%02d.%02d', m, s, ms)
end

---Format final LRC line
---combines timestamp and text
---@param start_time integer
---@param text string
---@return string
local function to_lrc_line(start_time, text)
	return string.format('[%s]%s\n', to_timecode(start_time), text)
end

---checks whether a given string ends with a substring
---TODO: This can be shortened instead of reversing 2 strings
---https://stackoverflow.com/a/72921992/3323286
---@param str any
---@param substr any
---@return boolean
local function endswith(str, substr)
	if str == nil or substr == nil then
		return false
	end
	local str_tmp = string.reverse(str)
	local substr_tmp = string.reverse(substr)
	if string.find(str_tmp, substr_tmp) ~= 1 then
		return false
	else
		return true
	end
end

---main macro function
---requests a file descriptor and writes the lines
---TODO: Add .elrc extension
---@param subs any
---@param sel any
local function ass_to_lyric(subs, sel)
	local filename = aegisub.dialog.save('Save Lyric File', '', '', 'Lyrics File(*lrc)|*lrc')
	
	if not filename then
		aegisub.cancel()
	end
	
	if endswith(string.lower(filename), '.lrc') == false then
		filename = filename .. '.lrc'
	end

	local output_file = io.open(filename, 'w+')
	if not output_file then
		aegisub.debug.out('Failed to open file')
		aegisub.cancel()
	end

---@diagnostic disable: need-check-nil -- Execution is canceled above
		output_file:write(utf8_bom())

		for i = 1, #subs, 1 do
			local line = subs[i]
			if line.class == 'dialogue' then
				output_file:write(to_lrc_line(line.start_time, strip_tags(line.text)))
			end
		end
	output_file:close()
---@diagnostic enable: need-check-nil
end

aegisub.register_macro(script_name, script_description, ass_to_lyric)
