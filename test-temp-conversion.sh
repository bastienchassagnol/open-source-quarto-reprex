#!/bin/bash

perl -0777 -pe '
  s/:::\s*(definition|theorem|example|corollary|proposition|conjecture|exercise|solution|remark)\s*\[\]\{#([^\s}]+).*?\}\s*/::: {#\2}\n\n/sg;
  s/::: proof\b/::: {.proof}/g;
  s/\n:::/\n\n:::/g
' chapter-3-justin-rmarkdown.qmd \
> chapter-3-justin-rmarkdown-good-format.qmd







