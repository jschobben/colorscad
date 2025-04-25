#!/usr/bin/env bash
set -o errexit -o errtrace -o nounset

# cd to this script's directory
X=$(command -v "$0")
cd "${X%${X##*/}}."

: "${OPENSCAD_CMD=openscad}"
COLORSCAD=$(pwd)/../colorscad.sh

# Use a temp dir relative to this script's dir, because openscad might not have access to the default
# temp dir; on i.e. Ubuntu, openscad can be a snap package which doesn't have access to /tmp/
TEMPDIR_REL=$(mktemp -d ./tmp.XXXXXX)
TEMPDIR="$(pwd)/${TEMPDIR_REL}"
trap "'${OPENSCAD_CMD}' --info 2>&1 | grep '^OpenSCAD Version: '; rm -Rf '$TEMPDIR'" EXIT

SKIP_3MF=0
OLD_BOOLEAN=0
for ARG in "$@"; do
	if [ "$ARG" = skip3mf ]; then
		SKIP_3MF=1
		echo "Will skip all tests that need 3mf support in openscad"
	elif [ "$ARG" = old_boolean ]; then
		OLD_BOOLEAN=1
		echo "Will setup tests to expect 'old' (<=2019.05) boolean semantics"
	fi
done


# Same as 'grep -q', without triggering broken pipe errors due to early exit
function grep_q {
	grep "$@" > /dev/null
}


# If a test fails, check if it's due to the used openscad version; if so, suggest workarounds.
function fail_tips {
	trap - ERR  # Prevent recursion
	if [ $SKIP_3MF -eq 0 ]; then
		if ! "$OPENSCAD_CMD" --info 2>&1 | grep '^lib3mf version: ' | grep_q -v 'not enabled'; then
			echo "Warning: all the 3MF tests will fail if your openscad version does not have 3mf support."
			echo "To skip those tests, use: $0 skip3mf"
			echo
		fi
	fi
	if [ $OLD_BOOLEAN -eq 0 ]; then
		(
			cd "$TEMPDIR"
			echo 'module empty(){}; intersection() {empty(); cube();}' > intersect.scad
			# <=2019.05 ignores the "empty" module, producing output; newer versions treat it as an empty volume.
			"$OPENSCAD_CMD" --quiet intersect.scad -o intersect.stl || true
			if [ -s intersect.stl ]; then
				echo "Warning: your openscad version uses 'old' boolean semantics."
				echo "To properly test on this version, use: $0 old_boolean"
				echo
			fi
			rm intersect.*
		)
	fi
	if ! "$OPENSCAD_CMD" --help 2>&1 | grep -q -- '--input'; then
		# On newer builds, 'predictible-output' must be enabled to get the same behavior as older ones
		echo "For OpenSCAD >= 2024.01.26, only a build with experimental features enabled will work."
	fi
}
trap 'echo "Failure at $0:$LINENO" >&2; fail_tips >&2' ERR


# Prepare given 3MF for comparison: strip UUIDs, and remove the "xmlns" attribute that not all versions add.
function canonicalize_3mf {
	local IN=$1
	local OUT_DIR=$2

	unzip -q "$IN" -d "$OUT_DIR"

	# Need to specify backup suffix for macOS compatibility; just remove unneeded backup
	sed -i.bak '
		s/UUID="[^"]*"//g;
		s/ xmlns:sc="[^"]*"//g;
	' "${OUT_DIR}/3D/3dmodel.model"
	rm "${OUT_DIR}/3D/3dmodel.model.bak"
}


# Prepare given AMF for comparison: sort vertices
function canonicalize_amf {
	local IN=$1
	local OUT_DIR=$2

	[[ -d "$OUT_DIR" ]] || mkdir "$OUT_DIR"
	# Split input in one object per line, then loop over each object
	cat "$IN" | tr -d '\r\n ' | sed 's#<object#\'$'\n''&#g' | while read OBJECT; do
		# Split object in lines, so each triangle and vertex is on its own line
		local OBJECT=$(echo "$OBJECT" | sed -E 's#<(triangle|/volume|vertex|/vertices)#\'$'\n''&#g')
		[ -n "$OBJECT" ]
		# The model contains vertices, plus triangles that index the vertices.
		# The vertices are in non-deterministic order, so they need to be sorted.
		# That obviously changes the triangle indices, so first replace these indices with coordinates.
		# 1) Store all vertices in an array
		local VERTICES=($(echo "$OBJECT" | grep '<vertex>' || true))
		# 2) Loop over each triangle, replacing the index of triangles with the vertex definition
		echo "$OBJECT" | grep '<triangle>' \
				| sed -E 's#<triangle><v1>(.*)</v1><v2>(.*)</v2><v3>(.*)</v3></triangle>#\1 \2 \3#g' \
				| while read TRIANGLE; do
			echo -n "<triangle>"
			for i in ${TRIANGLE}; do
				echo -n "${VERTICES[$i]}"
			done
			echo "</triangle>"
		done | sort
		# 3) Output the non-triangle lines, sorted
		echo "$OBJECT" | grep -v '<triangle>' | sort
	done > "${OUT_DIR}/model.amf"
}


# Convert the given input to AMF or 3MF, and verify that the output matches the given expectation.
# Whether to use AMF or 3MF, is derived from the expected output file's name.
function test_render {
	local INPUT=$1
	local EXPECTED=$2

	echo "Testing: input=${INPUT} expected=${EXPECTED}"

	if ! [ -e "$INPUT" ] || ! [ -e "$EXPECTED" ]; then
		echo "Error: could not find all files"
		return 1
	fi

	local FORMAT=${EXPECTED##*.}
	if [ "$FORMAT" = 3mf ] && [ $SKIP_3MF -ne 0 ]; then
		echo "  Skipping 3MF test"
		return
	fi
	if [ $FORMAT != 3mf ] && [ $FORMAT != amf ]; then
		echo "Format '${FORMAT}' unsupported"
		return 1
	fi

	# Generate output
	local OUTPUT="${TEMPDIR}/output.${FORMAT}"
	rm -f "$OUTPUT"
	# OpenSCAD >= 2024.01.26 with lib3mf v2 requires enabling "predictible-output" to get the same behavior as older versions
	(
		if "$OPENSCAD_CMD" --help 2>&1 | grep -q predictible-output; then
			export OPENSCAD_CMD_ORG=${OPENSCAD_CMD}
			function openscad_test_override { "$OPENSCAD_CMD_ORG" --enable=predictible-output "$@"; }
			export -f openscad_test_override
			export OPENSCAD_CMD=openscad_test_override
		fi
		${COLORSCAD} -i "$INPUT" -o "$OUTPUT" -j 4 > >(sed 's/^/  /') 2>&1
	)

	# Canonicalize the expectation and output, so they can be compared
	rm -Rf "${TEMPDIR}/exp" "${TEMPDIR}/out"
	mkdir "${TEMPDIR}/exp" "${TEMPDIR}/out"
	#trap 'rm -Rf "${TEMPDIR}/exp" "${TEMPDIR}/out"' RETURN
	canonicalize_${FORMAT} "$EXPECTED" "${TEMPDIR}/exp"
	canonicalize_${FORMAT} "$OUTPUT" "${TEMPDIR}/out"

	# Compare
	diff -wur "${TEMPDIR}/exp" "${TEMPDIR}/out"
}


# Make sure there's something to test
if ! command -v "$OPENSCAD_CMD" &> /dev/null; then
	echo "Error: ${OPENSCAD_CMD} command not found! Make sure it's in your PATH."
	exit 1
fi

# Nasty weather tests: check that the sanity checks catch all error conditions
echo "Testing bad weather:"
(
	mkdir "${TEMPDIR}"/nasty
	cd "${TEMPDIR}"/nasty
	${COLORSCAD} -i input -i input | grep_q "Error: '-i' specified more than once"
	${COLORSCAD} -o output -o output | grep_q "Error: '-o' specified more than once"
	(
		function sort { [ "$1" != --version ]; }
		export -f sort
		${COLORSCAD} | grep_q "your 'sort' command appears to be the wrong one"
	)
	${COLORSCAD} | grep_q 'You must provide both'
	echo 'color("red") cube();' > color.scad
	${COLORSCAD} -i color.scad | grep_q 'You must provide both'
	${COLORSCAD} -o output.amf | grep_q 'You must provide both'
	${COLORSCAD} -i missing.scad -o output.amf | grep_q "Input 'missing.scad' does not exist"
	echo 'cube();' > no_color.scad
	${COLORSCAD} -i no_color.scad -o output.amf | grep_q 'some geometry is not wrapped'
	touch existing.amf
	${COLORSCAD} -i color.scad -o existing.amf | grep_q "Output 'existing.amf' already exists"
	${COLORSCAD} -i color.scad -o wrong.ext | grep_q "the output file's extension must be one of 'amf' or '3mf'"
	(
		function command {
			if [ "$1" = -v ] && [ "$2" = "$OPENSCAD_CMD" ]; then return 1; fi
			builtin command "$@"
		}
		export -f command
		${COLORSCAD} -i color.scad -o output.amf | grep_q "${OPENSCAD_CMD} command not found"
	)
	OPENSCAD_CMD=i_am_not_here ${COLORSCAD} -i color.scad -o output.amf | grep_q 'i_am_not_here command not found'
	(
		trap 'echo "Failure on line $LINENO"; exit 1' ERR
		# If 'openscad --info' does not list 3mf support, it's a warning (followed by an abort due to this mock not producing output)
		function openscad_test_override { :; }
		export -f openscad_test_override
		export OPENSCAD_CMD=openscad_test_override
		${COLORSCAD} -i color.scad -o output.3mf | grep_q 'Warning: your openscad version does not seem to have 3MF support'
		function openscad_test_override { echo "lib3mf version: (not enabled)"; }
		${COLORSCAD} -i color.scad -o output.3mf | grep_q 'Warning: your openscad version does not seem to have 3MF support'
	)
	echo 'cheese' > syntax_error.scad
	${COLORSCAD} -i syntax_error.scad -o output.amf 2>&1 | grep_q "the produced file 'tmp\..*\.csg' is empty"
	echo '' > empty.scad
	${COLORSCAD} -i empty.scad -o output.amf | grep_q 'no colors were found at all'
)
echo "Bad weather tests all passed."


# Nice weather tests: check that the produced output matches the reference output

# Copy two tests to a nested dir, to check if colorscad can handle that
mkdir "${TEMPDIR}"/test_subdir
for x in test_color_args.scad test_import.scad; do
	sed -E 's#(use <|import\(")#\1../../#g' < $x > "${TEMPDIR}"/test_subdir/$x
done

# Run the tests
for x in test_*.scad "${TEMPDIR_REL}"/test_subdir/*.scad; do
	NAME=${x%.scad}
	EXPECTATION=${NAME##*/}
	if [ "$NAME" = test_boolean ] && [ $OLD_BOOLEAN -ne 0 ]; then
		EXPECTATION+='.2019.05'
	fi
	for EXT in 3mf amf; do
		test_render ${NAME}.scad expectations/${EXPECTATION}.${EXT}
	done
done

# Finally, rerun two tests with a different current directory
cd "$TEMPDIR"
for NAME in test_color_args test_import; do
	for EXT in 3mf amf; do
		test_render ../${NAME}.scad ../expectations/${NAME}.${EXT}
	done
done


echo "All tests passed"
if [ $SKIP_3MF -ne 0 ]; then
	echo "However, all 3mf tests were skipped"
fi
