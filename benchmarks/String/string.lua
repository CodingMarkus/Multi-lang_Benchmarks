local TARGET_SIZE = 1024 * 1024
local WORD_COUNT = 16
local LINE_LIMIT = 80
local FNV_OFFSET_HI = 0xcbf29ce4
local FNV_OFFSET_LO = 0x84222325
local FNV_PRIME_SMALL = 0x1b3
local REFERENCE_HASH_HI = 0xc6be9b92
local REFERENCE_HASH_LO = 0x67a2fb8e

function random_next(state)
	state.value = (state.value * 1664525 + 1013904223) % 4294967296
	return state.value
end


function multiply_hash(hi, lo)
	local low_product = lo * FNV_PRIME_SMALL
	local new_lo = low_product % 4294967296
	local carry = math.floor(low_product / 4294967296)
	local high_product =
		hi * FNV_PRIME_SMALL + carry + ((lo * 256) % 4294967296)
	local new_hi = high_product % 4294967296

	return new_hi, new_lo
end


function hash_bytes(text)
	local hash_hi = FNV_OFFSET_HI
	local hash_lo = FNV_OFFSET_LO

	for i = 1, #text do
		hash_lo = (hash_lo ~ string.byte(text, i)) % 4294967296
		hash_hi, hash_lo = multiply_hash(hash_hi, hash_lo)
	end

	return hash_hi, hash_lo
end


function build_source_text(words)
	local parts = {}
	local length = 0
	local word_count = 0
	local state = { value = 0x12345678 }

	while true do
		local word = words[(random_next(state) % WORD_COUNT) + 1]

		if word_count > 0 then
			table.insert(parts, " ")
			length = length + 1
		end

		table.insert(parts, word)
		length = length + #word
		word_count = word_count + 1

		if length > TARGET_SIZE then
			break
		end
	end

	local text = table.concat(parts)
	local hash_hi, hash_lo = hash_bytes(text)
	return text, word_count, hash_hi, hash_lo
end


function wrap_words(words)
	local parts = {}
	local line_length = 0

	for i = 1, #words do
		local word = words[i]
		local word_length = #word

		if i == 1 then
			table.insert(parts, word)
			line_length = word_length
		elseif line_length + 1 + word_length >= LINE_LIMIT then
			table.insert(parts, "\n")
			table.insert(parts, word)
			line_length = word_length
		else
			table.insert(parts, " ")
			table.insert(parts, word)
			line_length = line_length + 1 + word_length
		end
	end

	return table.concat(parts)
end


function hash_wrapped_text(text)
	local hash_hi = FNV_OFFSET_HI
	local hash_lo = FNV_OFFSET_LO
	local first = true

	for line in string.gmatch(text, "[^\n]+") do
		if not first then
			hash_lo = (hash_lo ~ 32) % 4294967296
			hash_hi, hash_lo = multiply_hash(hash_hi, hash_lo)
		end
		first = false

		for i = 1, #line do
			hash_lo = (hash_lo ~ string.byte(line, i)) % 4294967296
			hash_hi, hash_lo = multiply_hash(hash_hi, hash_lo)
		end
	end

	return hash_hi, hash_lo
end


function format_hash(hi, lo)
	return string.format("0x%08x%08x", hi, lo)
end


function run_benchmark(source_text, source_hash_hi, source_hash_lo, runs)
	for i = 1, runs do
		local split_words = {}
		for word in string.gmatch(source_text, "[^ ]+") do
			table.insert(split_words, word)
		end
		local wrapped_text = wrap_words(split_words)
		local wrapped_hi, wrapped_lo = hash_wrapped_text(wrapped_text)

		if wrapped_hi ~= source_hash_hi or wrapped_lo ~= source_hash_lo then
			io.stderr:write(
				"Hash mismatch: "
				.. format_hash(wrapped_hi, wrapped_lo)
				.. " != "
				.. format_hash(source_hash_hi, source_hash_lo)
				.. "\n"
			)
			os.exit(1)
		end
	end
end

local words = {
	"I",
	"we",
	"cat",
	"tree",
	"café",
	"naïve",
	"jalapeño",
	"mountain",
	"blueberry",
	"basketball",
	"grandfather",
	"microbiology",
	"determination",
	"responsibility",
	"experimentation",
	"counterclockwise"
}
local runs = 1
if arg[1] ~= nil then
	runs = tonumber(arg[1]) or 1
end

local source_text, source_word_count, source_hash_hi, source_hash_lo =
	build_source_text(words)
if (
	source_hash_hi ~= REFERENCE_HASH_HI or
	source_hash_lo ~= REFERENCE_HASH_LO
) then
	io.stderr:write(
		"Source hash mismatch: "
		.. format_hash(source_hash_hi, source_hash_lo)
		.. " != "
		.. format_hash(REFERENCE_HASH_HI, REFERENCE_HASH_LO)
		.. "\n"
	)
	os.exit(1)
end

local t = os.clock()
run_benchmark(source_text, source_hash_hi, source_hash_lo, runs)
local diff = os.clock() - t
io.stderr:write(string.format("Lua: %.3f s\n", diff))
