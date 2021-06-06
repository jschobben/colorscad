#!/bin/bash

OPENSCAD_EXTRA="";
PARALLEL_JOB_LIMIT=8

function usage {
cat <<EOF
Usage: $0 -i <input scad file> -o <output file>

Options
  -D  Variable to pass to Openscad, quoting hell, does some weird bits but input like
        you would give openscad direct works.  For example: -D 'var1="foofly"' -D 'var2="another thing"'
  -e  Openscad extra (freeform extra options to pass to Openscad)
  -f  Force, this will overwrite the output file if it exists
  -h  This msg you are reading
  -i  Input file
  -o  Output file must not yet exist, and must have as extension either '.amf' or '.3mf'.
  -p  MAX_PARALLEL_JOBS (defualt is 8) reduce if you're low on RAM.

EOF
}

while getopts :D:e:fi:o:p:h opt; do
  case "$opt" in
    D)
      OPENSCAD_EXTRA="$OPENSCAD_EXTRA -D '$OPTARG'"
    ;;
    e)
      OPENSCAD_EXTRA="$OPENSCAD_EXTRA $OPTARG"
    ;;
    f)
     force=1;
    ;;
    h)
     usage;
     exit;
    ;;
    i)
      INPUT="$OPTARG"
    ;;
    o)
      OUTPUT="$OPTARG"
    ;;
    p)
      PARALLEL_JOB_LIMIT="$OPTARG"
    ;;
    \?)
      echo "Unknown option: $OPTARG";
      exit;
    ;;
  esac
done



if [ "$(uname)" = Darwin ]; then
  # Add GNU coreutils to the path for macOS users (`brew install coreutils`).
  PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
fi

if [ -z "$OUTPUT" -o -z "$INPUT" ];then
  echo "You must provide both input (-i) and output (-o) files.  See help (-h)."
  exit 1
fi

if [ -e "$OUTPUT" ]; then
  if [ "$force" -eq 1 ];then
    rm "$OUTPUT"
  else
    echo "Output '$OUTPUT' already exists, aborting."
    exit 1
  fi
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
	if ! [ -x ${DIR_3MFMERGE}/bin/3mfmerge ] && ! [ -x ${DIR_3MFMERGE}/bin/3mfmerge.exe ]; then
		echo "3MF output depends on a binary tool, that needs to be compiled first."
		echo "Please see '3mfmerge/README.md' in the colorscad git repo (i.e. '${DIR_3MFMERGE}/')."
		exit 1
	fi
fi

if ! which openscad &> /dev/null; then
	echo "Error: openscad command not found! Make sure it's in your PATH."
	exit 1
fi


# Working directory, plus cleanup trigger
TEMPDIR=$(mktemp -d)
trap "rm -Rf '$TEMPDIR'" EXIT

# Convert input to a .csg file, mainly to resolve named colors. Also to evaluate functions etc. only once.
# Put .csg file in current directory, to be cygwin-friendly (Windows openscad doesn't know about /tmp/).
INPUT_CSG=$(mktemp --tmpdir=$TEMPDIR --suffix=.csg)

##  This is a bit hacky, I could not get quoting correct to pass in -D 'var="some test"' correct without xargs.
##    Seems really ugly, but it just was not playing nice.  Pass in like -D 'var1="foofly"' -D 'var2="another thing"' works now
##  Another note, openscad puts the output relative to the input, so changed it to full output path, with the added bonus utilizing
##    the same tempdir as everything else
openscad_cmd="\"$INPUT\" -o \"$INPUT_CSG\" $OPENSCAD_EXTRA";
echo "Running:  openscad $openscad_cmd";
echo "$openscad_cmd" |xargs openscad

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
echo -e "#####\n$COLORS\n#####"


# If "no_color.stl" contains anything, it's considered a fatal error:
# any geometry that doesn't have a color assigned, would end up in all per-color AMF files
if [ -s "${TEMPDIR}/no_color.stl" ]; then
	echo
	echo "Fatal error: some geometry is not wrapped in a color() module."
	echo "For a stacktrace, try running:"
	echo -n "openscad $OPENSCAD_EXTRA '$INPUT' -o output.csg -D 'module color(c,alpha=1){}"
	for primitive in cube sphere cylinder polyhedron; do
		echo -n " module ${primitive}(){assert(false);}"
	done
	echo "'"
	exit 1
fi

echo -e "\nCreate a separate .${INTERMEDIATE} file for each color"


function generate_csg {
  INPUT_CSG=$1;
  INTERMEDIATE=$2;
  TEMPDIR=$3;
  COLOR=$4;

  TEMPFILE=$(mktemp --tmpdir=. --suffix=.${INTERMEDIATE})
  echo "$COLOR Starting"
  openscad "$INPUT_CSG" -o "$TEMPFILE" -D "module color(c) {if (str(c) == \"${COLOR}\") children();}" 2>&1 |sed "s/^/$COLOR /g"
  if [ -s "$TEMPFILE" ]; then
    mv "$TEMPFILE" "${TEMPDIR}/${COLOR}.${INTERMEDIATE}"
  else
    echo "$COLOR Warning: output is empty!"
    rm "$TEMPFILE"
  fi
  echo "$COLOR finished at ${TEMPDIR}/${COLOR}.${INTERMEDIATE}";
}

command -v parallel > /dev/null
if [ $? -ne 0 ];then
  echo "WARNING:  You have thread count set to $PARALLEL_JOB_LIMIT however 'parallel' does not appear to be installed.";
  echo "Setting thread count to 1 to run in series, if you find generation too slow you should install 'parallel'"
  PARALLEL_JOB_LIMIT=1;
fi

if [ $PARALLEL_JOB_LIMIT -eq 1 ];then
  IFS=$'\n'
  for COLOR in $COLORS; do
    generate_csg $INPUT_CSG $INTERMEDIATE $TEMPDIR $COLOR
  done
else
  echo "$COLORS"
  export -f generate_csg
  echo "$COLORS" | parallel -P $PARALLEL_JOB_LIMIT generate_csg $INPUT_CSG $INTERMEDIATE $TEMPDIR
fi;

echo -e "\n###  Completed openscad CSG generation  ###\n"

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
		"${DIR_3MFMERGE}"/bin/3mfmerge merged.3mf < \
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
