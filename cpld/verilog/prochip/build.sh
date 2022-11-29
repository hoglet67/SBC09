#!/bin/bash

NAME=mmu

export ATF15XX_YOSYS=../../../../atf15xx_yosys

# Temporarily cope the source into the current directory
cat ../mmu.v ../mmu_int.v > ${NAME}.v

${ATF15XX_YOSYS}/run_yosys.sh ${NAME}
${ATF15XX_YOSYS}/run_fitter.sh ${NAME} $*

# Remove the temporary copy of the source
rm -f ${NAME}.v
