#!/bin/bash

cd wincupl
for pal in PAL1 PAL2
do
    echo "Building ${pal}"
    wine cupl.exe -m4 -jxfu cupl.dl ..\\${pal}\\${pal}.pld
done
cd ..
