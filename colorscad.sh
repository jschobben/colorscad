#!/bin/bash
INPUT=$1
PARALLEL_JOB_LIMIT=8

if [ -z "$INPUT" ]; then
	echo "Usage: $0 <scad file>"
	echo "An .amf file with the same name will be created in the current directory."
	exit 1
fi

OUTPUT=${INPUT%.scad}.amf
if [ -e "$OUTPUT" ]; then
	echo "Output '$OUTPUT' already exists, aborting."
	exit 1
fi

if ! which openscad &> /dev/null; then
	echo "Error: openscad command not found! Make sure it's in your PATH."
	exit 1
fi

# Convert input to a .csg file, mainly to resolve named colors. Also to evaluate functions etc. only once.
# Put .csg file in current directory, to be cygwin-friendly (Windows openscad doesn't know about /tmp/).
INPUT_CSG=$(mktemp --tmpdir=. --suffix=.csg)
openscad "$INPUT" -o "$INPUT_CSG"

# Working directory, plus cleanup trigger
TEMPDIR=$(mktemp -d)
trap "rm -Rf '$INPUT_CSG' '$TEMPDIR'" EXIT

echo "Get list of used colors"
# Colors are sorted on decreasing number of occurrences. The sorting is to gamble that more color mentions,
# means more geometry; we want to start the biggest jobs first to improve parallelism.
COLOR_ID_TAG="colorid_$$_${RANDOM}"
TEMPFILE=$(mktemp --tmpdir=. --suffix=.stl)
COLORS=$(
	openscad "$INPUT_CSG" -o "$TEMPFILE" -D "module color(c) {echo(${COLOR_ID_TAG}=str(c));}" 2>&1 |
	sed -n "s/\\r//g; s/\"//g; s/^ECHO: ${COLOR_ID_TAG} = // p" |
	sort |
	uniq -c |
	sort -rn |
	sed 's/^[^\[]*//'
)
mv "$TEMPFILE" "${TEMPDIR}/no_color.stl"

# If "no_color.stl" contains geometry, it's a fatal error.
# Any geometry that doesn't have a color assigned will end up in all per-color AMF files
if [ -s "${TEMPDIR}/no_color.stl" ]; then
	echo
	echo "Fatal error: some geometry is not wrapped in a color() module."
	echo "For a stacktrace, try running:"
	echo -n "openscad '$INPUT' -o output.csg -D 'module color(c,alpha=1){}"
	for primitive in cube sphere cylinder polyhedron; do
		echo -n " module ${primitive}(){assert(false);}"
	done
	echo "'"
	exit 1
fi

echo
echo "Create a separate .amf file for each color"
IFS=$'\n'
JOBS=0
for COLOR in $COLORS; do
	if [ $JOBS -ge $PARALLEL_JOB_LIMIT ]; then
		# Wait for one job to finish, before continuing
		echo "Busy, waiting..."
		wait -n
		let JOBS--
	fi
	(
		echo Starting...
		# To support Windows/cygwin, render to temp file in input directory and later move it to TEMPDIR.
		TEMPFILE=$(mktemp --tmpdir=. --suffix=.amf)
		openscad "$INPUT_CSG" -o "$TEMPFILE" -D "module color(c) {if (str(c) == \"${COLOR}\") children();}"
		mv "$TEMPFILE" "${TEMPDIR}/${COLOR}.amf"
		echo Done!
	) 2>&1 | sed "s/^/${COLOR} /" &
	let JOBS++
done
wait

echo
echo "Generate a merged .amf file"
{
	echo '<?xml version="1.0" encoding="UTF-8"?>'
	echo '<amf unit="millimeter">'
	echo ' <metadata type="producer">ColorSCAD</metadata>'
	id=0
	IFS=$'\n'
	for COLOR in $COLORS; do
		IFS=','; set -- $COLOR
		R=${1#[}
		G=$2
		B=$3
		A=${4%]}
		echo " <material id=\"${id}\"><color><r>${R// }</r><g>${G// }</g><b>${B// }</b><a>${A// }</a></color></material>"
		let id++
	done
	id=0
	IFS=$'\n'
	for COLOR in $COLORS; do
		echo " <object id=\"${id}\">"
		# Crudely skip the AMF header/footer; assume there is exactly one "<object>" tag and keep only its contents
		cat "${TEMPDIR}/${COLOR}.amf" | tail -n +5 | head -n -1 | sed "s/<volume>/<volume materialid=\"${id}\">/"
		let id++
	done
	echo '</amf>'
} > "$OUTPUT"

if which zip &> /dev/null; then
	echo
	echo "Zipping..."
	# The AMF spec says that the zip file should have exactly the same name as the .amf inside
	zip -m9 "${TEMPDIR}/output.zip" "$OUTPUT"
	mv "${TEMPDIR}/output.zip" "$OUTPUT"
fi

echo "Done"
