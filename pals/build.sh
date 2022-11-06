#!/bin/bash

cd wincupl
for pal in PAL1 PAL2 PAL3
do
    echo "Building ${pal}"
    wine cupl.exe -m2 -jxfu cupl.dl ..\\${pal}\\${pal}.pld
done
cd ..
