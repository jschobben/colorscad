#!/usr/bin/env bash

# Get this script's directory
DIR_SCRIPT="$(
	X=$(command -v "$0")
	cd "${X%"${X##*/}"}." || exit 1
	pwd
)"

function usage {
cat <<EOF
Usage: $0 -i <input scad file> -o <output file> [OTHER OPTIONS...] [-- OPENSCAD OPTIONS...]

Options
  -f  Force, this will overwrite the output file if it exists
  -h  This message you are reading
  -i  Input file
  -j  Maximum number of parallel jobs to use: defaults to 8, reduce if you're low on RAM
  -o  Output file: it must not yet exist (unless option -f is used),
      and must have as extension either '.amf' or '.3mf'
  -v  Verbose logging: mostly, this enables the OpenSCAD rendering stats output (default disabled)

Example which also includes some openscad options at the end:
  $0 -i input.scad -o output.3mf -f -j 4 -- -D 'var="some value"' --hardwarnings
EOF
}

FORCE=0
INPUT=
OUTPUT=
PARALLEL_JOB_LIMIT=8
VERBOSE=0
while getopts :fhi:j:o:v opt; do
	case "$opt" in
		f)
			FORCE=1;
		;;
		h)
			usage
			exit
		;;
		i)
			if [ -n "$INPUT" ]; then
				echo "Error: '-i' specified more than once"
				exit 1
			fi
			INPUT="$OPTARG"
		;;
		j)
			PARALLEL_JOB_LIMIT="$OPTARG"
		;;
		o)
			if [ -n "$OUTPUT" ]; then
				echo "Error: '-o' specified more than once"
				exit 1
			fi
			OUTPUT="$OPTARG"
		;;
		v)
			VERBOSE=1
		;;
		\?)
			echo "Unknown option: '-$OPTARG'. See help (-h)."
			exit 1
		;;
	esac
done
# Assign all parameters beyond '--' to OPENSCAD_EXTRA
shift "$((OPTIND-1))"
OPENSCAD_EXTRA=("$@")

if [ "$(uname)" = Darwin ]; then
	# BSD sed, as used on macOS, uses a different parameter than GNU sed to enable line-buffered mode
	function sed_u {
		sed -l "$@"
	}
else
	function sed_u {
		sed -u "$@"
	}
fi

# Bash 3 (shipped with macOS) does not support 'wait -n', so sleep instead.
# To upgrade bash on macOS, run: 'brew install bash'.
if [ "${BASH_VERSINFO[0]}" -lt 4 ]; then
	function wait_n {
		sleep 0.1
	}
else
	function wait_n {
		wait -n
	}
fi

# Sanity check: on Cygwin, sometimes PATH isn't setup properly and 'sort' starts the Windows version
if ! sort --version > /dev/null; then
	echo "Error: your 'sort' command appears to be the wrong one, it is now: $(command -v sort)"
	echo "Please fix your PATH, try: export PATH=/usr/bin:\$PATH"
	exit 1
fi

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
	echo "You must provide both input (-i) and output (-o) files. See help (-h)."
	exit 1
fi

if ! [ -e "$INPUT" ]; then
	echo "Input '$INPUT' does not exist, aborting."
	exit 1
fi

if [ -e "$OUTPUT" ] && [ "$FORCE" -ne 1 ]; then
	echo "Output '$OUTPUT' already exists, aborting."
	exit 1
fi

FORMAT=${OUTPUT##*.}
if [ "$FORMAT" != amf ] && [ "$FORMAT" != 3mf ]; then
	echo "Error: the output file's extension must be one of 'amf' or '3mf', but it is '$FORMAT'."
	exit 1
fi

if ! command -v openscad &> /dev/null; then
	echo "Error: openscad command not found! Make sure it's in your PATH."
	exit 1
fi

if [ "$FORMAT" = 3mf ]; then
	# Check if openscad was built with 3mf support
	if ! openscad --info 2>&1 | grep '^lib3mf version: ' | grep -qv 'not enabled'; then
		echo "Warning: your openscad version does not seem to have 3MF support, see 'openscad --info'."
		echo "Either update it, or use AMF output."
		echo
		# Not treating this as a fatal error, because '--info' sometimes fails and cause a false alarm.
	fi

	DIR_3MFMERGE=${DIR_SCRIPT}/3mfmerge
	if ! [ -x "${DIR_3MFMERGE}/bin/3mfmerge" ] && ! [ -x "${DIR_3MFMERGE}/bin/3mfmerge.exe" ]; then
		echo "3MF output depends on a binary tool, that needs to be compiled first."
		echo "Please see '3mfmerge/README.md' in the colorscad git repo (i.e. '${DIR_3MFMERGE}/')."
		exit 1
	fi
fi

# Convert OUTPUT to a full path, because we're going to change current directory (see below)
OUTPUT="$(cd "${OUTPUT%"${OUTPUT##*/}"}." || exit 1 ; pwd)/${OUTPUT##*/}"

# Change the current dir to the input's dir, for consistent behavior.
# That is because not all OpenSCAD versions behave the same when the input is not in the current dir;
# in some versions 'import()' is relative to the current dir instead of the input's dir, and in
# other versions .csg output is written relative to the input's dir, instead of the current dir.
ORIGINAL_PWD=$(pwd)
cd "${INPUT%"${INPUT##*/}"}." || exit 1
INPUT=${INPUT##*/}

# Create a temporary, unique .csg file in the input's directory.
# It needs to be in the input's directory, because it might contain relative "import" statements.
# On macOS, 'mktemp' does not expand the XXXs because there's a .csg suffix, so use a workaround.
INPUT_CSG=$(
	until mktemp "tmp.$$_${RANDOM}_XXXXXX.csg"; do sleep 1; done
)
[ -z "$INPUT_CSG" ] && exit
# Working directory. Use a dir relative to the input dir, because openscad might not have access to
# the default temp dir; on i.e. Ubuntu, openscad can be a snap package which doesn't have access to /tmp/
TEMPDIR=$(mktemp -d ./tmp.XXXXXX)
# Cleanup trigger
# shellcheck disable=SC2064
# this SHOULD expand now
trap "rm -Rf '$(pwd)/${INPUT_CSG}' '$(pwd)/${TEMPDIR}'" EXIT

# Convert input to a .csg file, mainly to resolve named colors. Also to evaluate functions etc. only once.
openscad "$INPUT" -o "$INPUT_CSG" "${OPENSCAD_EXTRA[@]}"

if ! [ -s "$INPUT_CSG" ]; then
	echo "Error: the produced file '$INPUT_CSG' is empty. Looks like something went wrong..."
	exit 1
fi

echo "Get list of used colors"
# Here we run openscad once on the .csg file, with a redefined "color" module that just echoes its parameters. There are two outputs:
# 1) The echoed color values, which are extracted, sorted and stored in COLORS.
# 2) Any geometry not wrapped in a color(), which is stored in TEMPDIR as "no_color.stl".
# Colors are sorted on decreasing number of occurrences. The sorting is to gamble that more color mentions,
# means more geometry; we want to start the biggest jobs first to improve parallelism.
COLOR_ID_TAG="colorid_$$_${RANDOM}"
COLORS=$(
	openscad "$INPUT_CSG" -o "${TEMPDIR}/no_color.stl" -D "module color(c) {echo(${COLOR_ID_TAG}=str(c));}" 2>&1 |
	tr -d '\r"' |
	sed -n "s/^ECHO: ${COLOR_ID_TAG} = // p" |
	sort |
	uniq -c |
	sort -rn |
	sed 's/^[^\[]*//'
)

# If "no_color.stl" contains anything, it's considered a fatal error:
# any geometry that doesn't have a color assigned, would end up in all per-color AMF files
if [ -s "${TEMPDIR}/no_color.stl" ]; then
	echo
	echo "Fatal error: some geometry is not wrapped in a color() module."
	echo "For a stacktrace, try running:"
	echo -n "  openscad"
	# Output quoted version of OPENSCAD_EXTRA, but exclude certain parameters that may confuse the stacktrace
	for PARAM in "${OPENSCAD_EXTRA[@]}"; do
		[ "$PARAM" = --hardwarnings ] && continue
		printf ' %q' "$PARAM"
	done
	echo -n " '$(pwd)/${INPUT}' -o output.csg -D 'module color(c,alpha=1){}"
	for primitive in cube sphere cylinder polyhedron; do
		echo -n " module ${primitive}(){assert(false);}"
	done
	echo "'"
	exit 1
fi

if [ -z "$COLORS" ]; then
	echo "Error: no colors were found at all. Looks like something went wrong..."
	exit 1
fi
COLOR_COUNT="$(echo "$COLORS" | wc -l)"
echo "${COLOR_COUNT} unique colors were found."
if [ $VERBOSE -eq 1 ]; then
	echo
	echo "List of colors found:"
	echo "$COLORS"
fi

echo
echo "Create a separate .${FORMAT} file for each color"

# Render INPUT_CSG, but only process geometry for the given color.
# Output is written to "$TEMPDIR/$COLOR.$FORMAT".
# Variables INPUT_CSG, FORMAT and TEMPDIR should be defined.
function render_color {
	local COLOR=$1

	{
		local OUT_FILE="${TEMPDIR}/${COLOR}.${FORMAT}"
		echo "Starting"
		local EXTRA_ARGS=
		if [ $VERBOSE -ne 1 ]; then
			EXTRA_ARGS=--quiet
		fi
		openscad "$INPUT_CSG" -o "$OUT_FILE" $EXTRA_ARGS -D "\$colored = false; module color(c) {if (\$colored) {children();} else {\$colored = true; if (str(c) == \"${COLOR}\") children();}}"
		if [ -s "$OUT_FILE" ]; then
			echo "Finished at ${OUT_FILE}"
		else
			echo "Warning: output is empty, removing it!"
			rm "$OUT_FILE"
		fi
	} 2>&1 | sed_u "s/^/${COLOR} /"
}

IFS=$'\n'
JOB_ID=0
for COLOR in $COLORS; do
	(( JOB_ID++ ))
	if [ "$(jobs | wc -l)" -ge "$PARALLEL_JOB_LIMIT" ]; then
		# Wait for one job to finish, before continuing
		wait_n
	fi
	# Run job in background, and prefix all terminal output with the job ID and color to show progress
	render_color "$COLOR" | sed_u "s/^/${JOB_ID}\/${COLOR_COUNT} /" &
done
# Wait for all remaining jobs to finish
wait

# Now sort colors by value, to reduce the need for remapping slicer colors when iteratively designing
COLORS=$(echo "$COLORS" | sort)

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
			IFS=, read -r R G B A <<<"${COLOR//[\[\] ]/}"
			echo " <material id=\"${id}\"><color><r>${R}</r><g>${G}</g><b>${B}</b><a>${A}</a></color></material>"
			(( id++ ))
		done
		id=0
		IFS=$'\n'
		for COLOR in $COLORS; do
			if grep -q -m 1 object "${TEMPDIR}/${COLOR}.amf"; then
				echo " <object id=\"${id}\">"
				# Crudely skip the AMF header/footer; assume there is exactly one "<object>" tag and keep only its contents.
				# At the same time, set the volume's material ID, and output the result.
				sed "1,4 d; \$ d; s/<volume>/<volume materialid=\"${id}\">/" "${TEMPDIR}/${COLOR}.amf"
			else
				echo "Skipping ${COLOR}!" >&2
				(( SKIPPED++ ))
			fi
			(( id++ ))
			echo -ne "\r  ${id}/${COLOR_COUNT} " >&2
		done
		echo '</amf>'
	} > "$OUTPUT"

	# Strip original current dir prefix, if present, to make message smaller
	OUT=${OUTPUT#"${ORIGINAL_PWD}"/}
	echo
	echo "To create a compressed AMF, run:"
	echo "  zip '${OUT}.zip' '$OUT' && mv '${OUT}.zip' '${OUT}'"
	echo "But, be aware that some tools may not support compressed AMF files."

	if [ "$SKIPPED" -gt 0 ]; then
		echo "Warning: ${SKIPPED} input files were skipped!"
		MERGE_STATUS=1
	fi
elif [ "$FORMAT" = 3mf ]; then
	# Run from inside TEMPDIR, to support having a Windows-format 3mfmerge binary
	(
		cd "$TEMPDIR" || exit 1
		# shellcheck disable=SC2001
		"${DIR_3MFMERGE}"/bin/3mfmerge merged.3mf < \
		  <(echo "$COLORS" | sed "s/\$/\.${FORMAT}/")
	)
	MERGE_STATUS=$?
	if ! [ -s "${TEMPDIR}"/merged.3mf ]; then
		echo "Merging failed, aborting!"
		exit 1
	fi
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
