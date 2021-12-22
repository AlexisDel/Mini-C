#!/bin/bash

dune build

EXTENSION="./tests/extensions/*.mnc"
for f in $EXTENSION
do
	echo "File : $f"
	./_build/default/minic.exe "$f"
	printf "\n"

done

NOYAU="./tests/noyau/*.mnc"
for f in $NOYAU
do
	echo "File : $f"
	./_build/default/minic.exe "$f"
	printf "\n"

done