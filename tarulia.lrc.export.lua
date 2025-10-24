local tr = aegisub.gettext
---@diagnostic disable: lowercase-global --  Aegisub requires lowercase
script_name = tr"LRC/Export File"
script_description = tr"Export Lyric File For Aegisub"
script_author = "Tarulia & ema"
script_version = "1"
---@diagnostic enable: lowercase-global

---@diagnostic disable-next-line - "Undefined global `include`.(You can treat `include` as `require` by setting.)" no idea what setting
include("karaskel.lua")

--
--	Utility functions
--

---checks whether a given string ends with a substring<br>
---https://stackoverflow.com/a/72921992/3323286
---@param self string
---@param suffix string
---@return boolean
function string:endswith(suffix)
    return self:sub(-#suffix) == suffix
end

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
--dump an entire table withour values<br>
---necessary for big tables that run into a stack overflow<br>
---https://stackoverflow.com/a/27028488/3323286
---@param o table
---@return string
local function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. ','-- .. dump(v)
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

---dump an entire table with values<br>
---necessary for big tables that run into a stack overflow<br>
---https://stackoverflow.com/a/27028488/3323286
---@param o table
---@return string
local function dump_full(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump_full(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--
--	LRC Generation
--

---Format final LRC line<br>
---combines formatted timestamp and text
---@param start_time integer
---@param text string
---@return string
local function to_lrc_line(start_time, text)
	return string.format('[%s]%s\n', to_timecode(start_time), text)
end

---Requests a file, checks extension, then opens file descriptor and writes UTF-8 BOM
---@param extension string including dot
---@return file*?
local function start_lyrics_file(extension)
	local filename = aegisub.dialog.save('Save Lyric File', '', '', string.format('Lyrics File (*%s)|*%s',extension,extension))
	
	if not filename then
		aegisub.cancel()
	end

	if string.lower(filename):endswith(extension) ~= true then
		filename = filename .. extension
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

--
-- Register Macro functions
--

---Macro: LRC<br>
---requests a file descriptor and writes the lines<br>
---LRC - Strips k-timings
---@param subs table
---@param sel table
local function ass_to_lrc(subs, sel)
	local output_file = start_lyrics_file(".lrc")

	for i = 1, #subs, 1 do
		local line = subs[i]
		if line.class == 'dialogue' and line.comment == false then
			---@diagnostic disable-next-line: need-check-nil -- canceled in start_lyrics_file
			output_file:write(to_lrc_line(line.start_time, strip_tags(line.text)))
		end
	end

	---@diagnostic disable-next-line: need-check-nil -- canceled in start_lyrics_file
	output_file:close()

	aegisub.log(3, 'LRC Export finished')
end

---Macro: eLRC<br>
---requests a file descriptor and writes the lines<br>
---eLRC - Includes k-timings as angle-bracket tags
---@param subs table
---@param sel table
local function ass_to_elrc(subs, sel)
	local output_file = start_lyrics_file(".elrc")

	local meta, styles = karaskel.collect_head(subs)

	for lineCounter = 1, #subs, 1 do
		local line = subs[lineCounter]

		--aegisub.log(3, 'type(line): %s\n', type(line))
		if line.class == 'dialogue' and line.comment == false then
			aegisub.log(5, 'BEFORE preproc_line_text\n')
			aegisub.log(5, 'dump_full(line):\n%s\n\n', dump_full(line))
			karaskel.preproc_line_text(meta, styles, line)
			aegisub.log(5, 'AFTER preproc_line_text\n')
			aegisub.log(5, 'dump_full(line):\n%s\n\n', dump_full(line))
			aegisub.log(5, 'dump_full(line.kara):\n%s\n\n', dump_full(line.kara))

			local elrcLine = ''
			local syl
			for sylCounter = 1, #line.kara, 1 do
				syl = line.kara[sylCounter]
				aegisub.log(5, '\nline.start_time: %s\n', line.start_time)
				aegisub.log(5, 'sylCounter: %s\n', sylCounter)
				aegisub.log(5, 'dump(syl):\n%s\n', dump(syl))
				aegisub.log(5, 'dump_full(syl.duration): %s\n', dump_full(syl.duration))
				aegisub.log(5, 'dump_full(syl.kdur): %s\n', dump_full(syl.kdur))
				aegisub.log(5, 'dump_full(syl.start_time): %s\n', dump_full(syl.start_time))
				aegisub.log(5, 'dump_full(syl.end_time): %s\n', dump_full(syl.end_time))
				aegisub.log(5, 'dump_full(syl.text): %s\n', dump_full(syl.text))
				elrcLine = string.format('%s<%s>%s<%s>',
							elrcLine,
							to_timecode(line.start_time + syl.start_time),
							syl.text,
							to_timecode(line.start_time + syl.end_time)
						   )
			end
			aegisub.log(4, 'elrcLine: %s\n', elrcLine)

			---@diagnostic disable-next-line: need-check-nil -- canceled in start_lyrics_file
			output_file:write(to_lrc_line(line.start_time, elrcLine))
		end
	end

	---@diagnostic disable-next-line: need-check-nil -- canceled in start_lyrics_file
	output_file:close()

	aegisub.log(3, 'eLRC Export finished')
end

aegisub.register_macro(script_name .. ' - LRC', script_description .. ' - Simple LRC format', ass_to_lrc)
aegisub.register_macro(script_name .. ' - eLRC', script_description .. ' - Enhanced LRC format', ass_to_elrc)
