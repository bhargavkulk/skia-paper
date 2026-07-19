#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DIFF_DIR="$ROOT_DIR/diff"
OLD_DIR="$DIFF_DIR/old"
NEW_DIR="$DIFF_DIR/new"
IMAGE_DIR="$DIFF_DIR/images"
RAW_DIFF="$DIFF_DIR/diff.raw.tex"
DIFF_TEX="$DIFF_DIR/diff.tex"
DIFF_PDF="$DIFF_DIR/diff.pdf"

OLD_REV=$(git -C "$ROOT_DIR" rev-parse --verify 'refs/heads/oopsla-submission^{commit}')
NEW_REV=$(git -C "$ROOT_DIR" rev-parse --verify 'HEAD^{commit}')

printf 'Clearing %s\n' "$DIFF_DIR"
rm -rf "$DIFF_DIR"
mkdir -p "$OLD_DIR" "$NEW_DIR" "$IMAGE_DIR"

printf 'Exporting oopsla-submission (%s)\n' "$OLD_REV"
git -C "$ROOT_DIR" archive --format=tar "$OLD_REV" | tar -xf - -C "$OLD_DIR"
printf 'Exporting HEAD (%s)\n' "$NEW_REV"
git -C "$ROOT_DIR" archive --format=tar "$NEW_REV" | tar -xf - -C "$NEW_DIR"

build_snapshot() {
    local snapshot_dir=$1
    local log_file="$snapshot_dir/build.log"

    (
        cd "$snapshot_dir"
        pdflatex -interaction=nonstopmode main.tex >"$log_file" 2>&1
        bibtex main >>"$log_file" 2>&1
        pdflatex -interaction=nonstopmode main.tex >>"$log_file" 2>&1
        pdflatex -interaction=nonstopmode main.tex >>"$log_file" 2>&1
        test -s main.bbl
    )
}

printf 'Building bibliography for oopsla-submission\n'
build_snapshot "$OLD_DIR"
printf 'Building bibliography for HEAD\n'
build_snapshot "$NEW_DIR"

cp -R "$OLD_DIR/images/." "$IMAGE_DIR/"
cp -R "$NEW_DIR/images/." "$IMAGE_DIR/"

printf 'Generating LaTeX diff\n'
latexdiff --flatten "$OLD_DIR/main.tex" "$NEW_DIR/main.tex" \
    >"$RAW_DIFF" 2>"$DIFF_DIR/latexdiff.log"

printf 'Removing intermediate document terminators\n'
# The subfile sources contain standalone terminators. Remove those from the
# flattened intermediate and add one terminator for the combined document.
awk '$0 != "\\end{document}" { print } END { print "\\end{document}" }' \
    "$RAW_DIFF" >"$DIFF_TEX"

printf 'Compiling diff PDF\n'
(
    cd "$DIFF_DIR"
    if ! pdflatex -interaction=nonstopmode diff.tex >diff-build.log 2>&1; then
        printf 'Warning: first diff LaTeX pass reported errors; see %s\n' "$DIFF_DIR/diff-build.log" >&2
    fi
    if ! pdflatex -interaction=nonstopmode diff.tex >>diff-build.log 2>&1; then
        printf 'Warning: second diff LaTeX pass reported errors; see %s\n' "$DIFF_DIR/diff-build.log" >&2
    fi
)

test -s "$DIFF_PDF"
printf 'Generated %s\n' "$DIFF_PDF"
printf 'Compared %s (oopsla-submission) to %s (HEAD)\n' "$OLD_REV" "$NEW_REV"
