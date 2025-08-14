#!/bin/bash

# Ensure clean temporary space
TMP_DIR=$(mktemp -d)
# trap 'rm -rf "$TMP_DIR"' EXIT

# Define the log file
LOG_FILE="convert_tex_to_qmd-$(date +%F).log"

# Loop through all .tex files in the directory
for tex_file in *.tex; do
  base=$(basename "$tex_file" .tex)
  qmd_pandoc="$TMP_DIR/${base}_pandoc.qmd"
  qmd_mathfix="$TMP_DIR/${base}_mathfix.qmd"
  qmd_mathclean="$TMP_DIR/${base}_mathclean.qmd"
  qmd_refs="$TMP_DIR/${base}_refs.qmd"
  qmd_final="${base}.qmd"

  echo "▶ Converting: $tex_file → $qmd_final" >> "$LOG_FILE"

  echo "• Step 1: Pandoc conversion to markdown..." >> "$LOG_FILE"
  pandoc \
    -f latex+smart \
    -t markdown-smart+hard_line_breaks \
    "$tex_file" \
    --reference-location=section \
    --preserve-tabs \
    --wrap=auto \
    --columns=72 \
    -o "$qmd_pandoc" \
    2>&1 | tee -a "$LOG_FILE"


  echo "• Step 2.i: Fix math environments..." >> "$LOG_FILE"
  perl -0777 -pe '
      s/\$\$/\n\$\$\n/g; # Step 1: add newlines around $$
      s/\n{3,}/\n\n/g;                # Step 2: collapse 3+ newlines to 2
      s/\$\$(.*?)\\label\{(eq:[^}]+)\}(.*?)\$\$/\$\$\1\3\$\$ {#\2}/gs;  # Step 3: fix labels
  ' "$qmd_pandoc" > "$qmd_mathfix" 2>&1

  echo "• Step 2.ii: Remove empty lines in math blocks..." >> "$LOG_FILE"
  awk '
    BEGIN { in_math = 0 }
    /^\$\$/ {
      print
      in_math = 1 - in_math
      next
    }
    in_math {
      if ($0 ~ /^[[:space:]]*$/) next
    }
    { print }
  ' "$qmd_mathfix" > "$qmd_mathclean"

  echo "• Step 3.i: Convert hyperref and labels to Quarto cross-references..." >> "$LOG_FILE"
  perl -pe '
    # Remove hyperrefs used instead of proper cross-references
    s/(fig|tbl|tab|table|lst|tip|nte|wrn|imp|cau|thm|lem|cor|prp|cnj|def|exm|exr|ex|exercise|sol|rem|eq|sec|foot|chap):/\1-/g;
    s/(Footnote|Appendix|Chapter|Section|Figure|Table|Equation|Example|Theorem|Definition|Corollary|Proof|Remark|Exercise) \[\\\[([^\]]+)\\\]\]\(#\2\)\{reference-type="ref" reference="\2"\}/@\2/g;
    s/(Footnote|Appendix|Chapter|Section|Figure|Table|Exercise) \[[^\]]+\]\(#([^)]+)\)\{reference-type="ref" reference="\2"\}/@\2/g;
    s/\[\d+(?:\.\d+)?\]\(#((fig|tab|sec|chap)-[^)]+)\)\{reference-type="ref" reference="\1"\}/@\1/g;
    s/\[\\\[([a-z]+-[^\]]+)\\\]\]\(#\1\)\{reference-type="ref" reference="\1"\}/@\1/g;

    # Use proper prefixes for labels
    s/\b(table|tab)[:\-]/tbl-/g;
    s/\bex[:\-]/exm-/g;
    s/\bexercise[:\-]/exr-/g;
    s/\bchap[:\-]/sec-/g;

    # Replace underscores by hyphens.
    s{([@#](?:fig|tbl|lst|tip|nte|wrn|imp|cau|thm|lem|cor|prp|cnj|def|exm|exr|sol|rem|eq|sec|foot)[^\s\}]+)}{
        my $lbl = $1;
        $lbl =~ s/_/-/g;
        $lbl =~ s/[^A-Za-z0-9-@#]//g;
        $lbl
    }ge
  '  "$qmd_mathclean" > "$qmd_final" 2>&1

  echo "✅ Finished: conversion: $qmd_final"  >> "$LOG_FILE"
  echo "----------------------------------------" >> "$LOG_FILE"
  done

echo "All conversions completed on $(date)" >> "$LOG_FILE"

rm -rf "$TMP_DIR"
echo "🧹 All temporary files cleaned up."

