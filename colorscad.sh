#!/bin/bash
INPUT=$1
OUTPUT=$2
PARALLEL_JOB_LIMIT=${3:-8}

if [ -z "$OUTPUT" ]; then
	echo "Usage: $0 <input scad file> <output file> [MAX_PARALLEL_JOBS]"
	echo "The output file must not yet exist, and must have as extension either '.amf' or '.3mf'."
	echo "MAX_PARALLEL_JOBS defaults to 8, reduce if you're low on RAM."
	exit 1
fi

if [ -e "$OUTPUT" ]; then
	echo "Output '$OUTPUT' already exists, aborting."
	exit 1
fi
FORMAT=${OUTPUT##*.}
if [ "$FORMAT" != amf ] && [ "$FORMAT" != 3mf ]; then
	echo "Error: the output file's extension must be one of 'amf' or '3mf', but it is '$FORMAT'."
	exit 1
fi
INTERMEDIATE=$FORMAT # Format of the per-color intermediate results.
# Lib3MF does not seem to like OpenSCAD's .stl format, otherwise colored 3mf export would be possible with 2015.03 too.

if [ "$FORMAT" = 3mf ]; then
	DIR_3MFMERGE=$(readlink -f ${0%/*})/3mfmerge
	if ! [ -x ${DIR_3MFMERGE}/build/3mfmerge ] && ! [ -x ${DIR_3MFMERGE}/build/3mfmerge.exe ]; then
		echo "3MF output depends on a binary tool, that needs to be compiled first."
		echo "Please see '3mfmerge/README.md' in the colorscad git repo (i.e. '${DIR_3MFMERGE}/')."
		exit 1
	fi
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
# Here we run openscad once on the .csg file, with a redefined "color" module that just echoes its parameters. There are two outputs:
# 1) The echoed color values, which are extracted, sorted and stored in COLORS.
# 2) Any geometry not wrapped in a color(), which is stored in TEMPDIR as "no_color.stl".
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
COLOR_COUNT=$(echo "$COLORS" | wc -l)
echo "${COLOR_COUNT} unique colors were found."

# If "no_color.stl" contains anything, it's considered a fatal error:
# any geometry that doesn't have a color assigned, would end up in all per-color AMF files
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
echo "Create a separate .${INTERMEDIATE} file for each color"
IFS=$'\n'
ACTIVE_JOBS=0
JOB_ID=0
COMPLETED=0
for COLOR in $COLORS; do
	let JOB_ID++
	if [ $ACTIVE_JOBS -ge $PARALLEL_JOB_LIMIT ]; then
		# Wait for one job to finish, before continuing
		wait -n
		let ACTIVE_JOBS--
		let COMPLETED++
		echo -ne "Jobs completed: ${COMPLETED}/${COLOR_COUNT} \r"
	fi
	# Run job in background, and prefix all terminal output with the job ID and color to show progress
	(
		# To support Windows/cygwin, render to temp file in input directory and later move it to TEMPDIR.
		TEMPFILE=$(mktemp --tmpdir=. --suffix=.${INTERMEDIATE})
		openscad "$INPUT_CSG" -o "$TEMPFILE" -D "module color(c) {if (str(c) == \"${COLOR}\") children();}"
		if [ -s "$TEMPFILE" ]; then
			mv "$TEMPFILE" "${TEMPDIR}/${COLOR}.${INTERMEDIATE}"
		else
			echo "Warning: output is empty!"
			rm "$TEMPFILE"
		fi
	) 2>&1 | sed "s/^/${JOB_ID}\/${COLOR_COUNT} ${COLOR} /" &
	let ACTIVE_JOBS++
done
# Wait for all remaining jobs to finish
while [ $ACTIVE_JOBS -gt 0 ]; do
	wait -n 1
	let ACTIVE_JOBS--
	let COMPLETED++
	echo -ne "Jobs completed: ${COMPLETED}/${COLOR_COUNT} \r"
done
echo

echo
echo "Generate a merged .${FORMAT} file"
MERGE_STATUS=0
if [ "$FORMAT" = amf ]; then
	SKIPPED=0
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
			if grep -q -m 1 object "${TEMPDIR}/${COLOR}.amf"; then
				echo " <object id=\"${id}\">"
				# Crudely skip the AMF header/footer; assume there is exactly one "<object>" tag and keep only its contents
				cat "${TEMPDIR}/${COLOR}.amf" | tail -n +5 | head -n -1 | sed "s/<volume>/<volume materialid=\"${id}\">/"
			else
				echo "Skipping ${COLOR}!" >&2
				let SKIPPED++
			fi
			let id++
			echo -ne "\r${id}/${COLOR_COUNT} " >&2
		done
		echo '</amf>'
	} > "$OUTPUT"

	echo
	echo "To create a compressed AMF, run:"
	echo "  zip '${OUTPUT}.zip' '$OUTPUT' && mv '${OUTPUT}.zip' '${OUTPUT}'"
	echo "But, be aware that some tools may not support compressed AMF files."

	if [ "$SKIPPED" -gt 0 ]; then
		echo "Warning: ${SKIPPED} input files were skipped!"
		MERGE_STATUS=1
	fi
elif [ "$FORMAT" = 3mf ]; then
	# Run from inside TEMPDIR, to support having a Windows-format 3mfmerge binary
	(
		cd "$TEMPDIR"
		"${DIR_3MFMERGE}"/build/3mfmerge merged.3mf < \
				<(echo "$COLORS" | sed "s/\$/\.${INTERMEDIATE}/")
	)
	MERGE_STATUS=$?
	mv "${TEMPDIR}"/merged.3mf "$OUTPUT"
else
	echo "Merging of format '${FORMAT}' not yet implemented!"
	exit 1
fi

echo
echo -n "${OUTPUT} created"
if [ "${MERGE_STATUS}" -eq 0 ]; then
	echo " successfully."
else
	echo ", but there were some problems (merge step exit status: ${MERGE_STATUS})."
fi
