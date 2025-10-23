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
---@param time_ms integer
---@return string
local function to_timecode(time_ms)
	local time_sec = time_ms / 1000
	local h = math.floor(time_sec / 3600)
	local m = math.floor(time_sec % 3600 / 60)
	local s = math.floor(time_sec % 60)
	local ms = math.floor( ((time_sec % 60) - math.floor(time_sec % 60)) * 100 )
	aegisub.log(4,'timesec: %s | h: %s | m: %s | s: %s | ms: %s\n', time_sec, h, m, s, ms)
	m = m + h * 60
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

---Requests a file, checks extension, then opens file descriptor and writes UTF-8 BOM
---@param extension string
---@return file*?
local function start_lyrics_file(extension)
	local filename = aegisub.dialog.save('Save Lyric File', '', '', string.format('Lyrics File (*.%s)|*.%s',extension,extension))
	
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

		---@diagnostic disable-next-line: need-check-nil -- canceled above
		output_file:write(utf8_bom())

	return output_file
end

---main macro function
---requests a file descriptor and writes the lines
---TODO: Add .elrc extension
---@param subs table
---@param sel table
local function ass_to_lrc(subs, sel)
	local output_file = start_lyrics_file("lrc")

	for i = 1, #subs, 1 do
		local line = subs[i]
		-- TODO: Filter out line.comment to allow actual comments in the file
		if line.class == 'dialogue' then
			---@diagnostic disable-next-line: need-check-nil -- canceled in start_lyrics_file
			output_file:write(to_lrc_line(line.start_time, strip_tags(line.text)))
		end
	end

	---@diagnostic disable-next-line: need-check-nil -- canceled in start_lyrics_file
	output_file:close()
end

aegisub.register_macro(script_name, script_description, ass_to_lrc)
