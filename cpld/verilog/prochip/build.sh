#!/bin/bash

NAME=mmu

export ATF15XX_YOSYS=../../../../atf15xx_yosys

cp ../${NAME}.v .
${ATF15XX_YOSYS}/run_yosys.sh ${NAME}
${ATF15XX_YOSYS}/run_fitter.sh ${NAME}
