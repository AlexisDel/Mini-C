#!/bin/bash

dune build

INTERPRETE="./tests/interprete/*.mnc"
for f in $INTERPRETE
do
	echo "File : $f"
	./_build/default/minic.exe "$f"
	printf "\n"

done