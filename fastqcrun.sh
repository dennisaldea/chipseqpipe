#!/usr/bin/env bash

###############################################################################
# title       : fastqcrun.sh                                                  #
# description : This script executes FastQC on raw sequence FASTQ files in    #
#               parallel.                                                     #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-05                                                    #
###############################################################################

# import chip-seq analysis library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $SCRIPT_DIR/chipseqlib.sh

# fastqc_raw_fastqs <tissue> <replicate>
# Runs FastQC on raw sequence FASTQ files of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate numbet of sample
fastqc_raw_fastqs () {
  local tissue="$1"
  local replicate="$2"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local for_fq="$(get_raw_fastq $tissue $replicate forward)"
  run_fastqc $for_fq $data_dir &
  local rev_fq="$(get_raw_fastq $tissue $replicate reverse)"
  run_fastqc $rev_fq $data_dir &
}

# main
# Driver function
main () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      fastqc_raw_fastqs $tissue $replicate &
    done
  done
  wait
}

main
