#!/bin/sh

# Copyright 2026 CodingMarkus
#
# SPDX-License-Identifier: Unlicense

set -eu

if [ "$#" -ne 4 ]
then
	printf 'Usage: %s <readme> <svg> <title> <column>\n' "$0" >&2
	exit 1
fi

awk -F'|' -v title="$3" -v metric="$4" '
	function xml(text) {
		gsub(/&/, "\\&amp;", text)
		gsub(/</, "\\&lt;", text)
		gsub(/>/, "\\&gt;", text)
		return text
	}
	$2 ~ /Language/ {
		inTable = 1
		for (field = 3; field <= NF; field++) {
			if (metric == "benchmark" && $field ~ /Benchmark/) \
				column = field
			if (metric == "binary" && $field ~ /Binary/) column = field
			if (metric == "memory" && $field ~ /Memory/) column = field
		}
		next
	}
	inTable && $2 ~ /---/ { next }
	inTable && NF >= column {
		if (metric == "binary" && $column + 0 == 0) next
		label[++count] = $2
		gsub(/^[[:space:]]+|[[:space:]]+$/, "", label[count])
		value[count] = $column + 0
		if (value[count] > maximum) maximum = value[count]
		next
	}
	inTable { inTable = 0 }
	END {
		width = 1280
		left = 300
		right = 40
		top = 60
		rowHeight = 48
		barHeight = 26
		plotWidth = width - left - right
		height = top + count * rowHeight + 84
		step = 1
		while (step * 5 < maximum) step *= 2
		axisMaximum = step * 5
		numberFormat = metric == "binary" ? "%.0f" : "%.3f"
		print "<svg xmlns=\047http://www.w3.org/2000/svg\047" \
			" width=\047" width "\047 height=\047" height \
			"\047 viewBox=\0470 0 " width " " height "\047>"
		print "<rect width=\047100%\047 height=\047100%\047" \
			" fill=\047white\047/>"
		print "<style>text{font-family:Arial,sans-serif;fill:#202124}" \
			".grid{stroke:#d8d8d8;stroke-dasharray:4 4}" \
			".axis{stroke:#777;stroke-width:1.5}</style>"
		print "<text x=\047640\047 y=\04732\047" \
			" font-family=\047Arial Bold,Arial,sans-serif\047" \
			" font-size=\04724\047 font-weight=\047bold\047" \
			" text-anchor=\047middle\047>" xml(title) "</text>"
		for (tick = 0; tick <= axisMaximum; tick += step) {
			x = left + plotWidth * tick / axisMaximum
			print "<line x1=\047" x "\047 y1=\047" top "\047" \
				" x2=\047" x "\047 y2=\047" height - 54 \
				"\047 class=\047grid\047/>"
			printf "<text x=\047%.1f\047 y=\047%.1f\047" \
				" font-size=\04716\047 text-anchor=\047middle\047" \
				">" numberFormat "</text>\n", x, height - 30, tick
		}
		print "<line x1=\047" left "\047 y1=\047" top "\047" \
			" x2=\047" left "\047 y2=\047" height - 54 \
			"\047 class=\047axis\047/>"
		print "<line x1=\047" left "\047 y1=\047" height - 54 \
			"\047 x2=\047" width - right "\047 y2=\047" height - 54 \
			"\047 class=\047axis\047/>"
		for (row = 1; row <= count; row++) {
			y = top + (row - 1) * rowHeight + 11
			barWidth = plotWidth * value[row] / axisMaximum
			printf "<text x=\047%d\047 y=\047%.1f\047 font-size=\04718\047" \
				" text-anchor=\047end\047>%s</text>\n", left - 14, y + 19, \
				xml(label[row])
			printf "<rect x=\047%d\047 y=\047%.1f\047 width=\047%.1f\047" \
				" height=\047%d\047 rx=\0472\047 fill=\047%s\047/>\n", \
				left, y, barWidth, barHeight, "#4c78a8"
			printf "<text x=\047%.1f\047 y=\047%.1f\047" \
				" font-family=\047Arial Bold,Arial,sans-serif\047" \
				" font-size=\04716\047 font-weight=\047bold\047" \
				">" numberFormat "</text>\n", left + barWidth + 8, y + 19, value[row]
		}
		print "</svg>"
	}
' "$1" > "$2"
