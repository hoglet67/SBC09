#!/bin/bash

for pal in PAL1 PAL2
do
    rm -f ${pal}/${pal}.pld~
    rm -f ${pal}/${pal}.doc
    rm -f ${pal}/${pal}.lst
    rm -f ${pal}/${pal}.jed
    rm -f ${pal}/runfit*
done
