#!/bin/sh

# Copyright 2026 CodingMarkus
#
# SPDX-License-Identifier: Unlicense

set -eu

scriptDirectory=$(CDPATH='' cd "$(dirname "$0")" && pwd)
projectDirectory=$(CDPATH='' cd "$scriptDirectory/.." && pwd)
markshupPath=${MARKSHUP_BINARY:-$projectDirectory/util/lib/site/markshup}
siteDirectory=$projectDirectory/site
generatedDirectory=$siteDirectory/generated
footerPath=$projectDirectory/util/assets/site/footer.html
headerPath=$projectDirectory/util/assets/site/header.html
templatesPath=$projectDirectory/util/assets/site/templates

rm -rf "$generatedDirectory"
mkdir -p "$generatedDirectory"

"$markshupPath" \
	--recursive \
	--mangle kebab \
	--no-copy-files \
	--templates "$templatesPath" \
	--css "$siteDirectory/css/footer.css" \
	--header "$headerPath" \
	--footer "$footerPath" \
	-- "$projectDirectory" "$generatedDirectory"
