#!/usr/bin/env bash

###############################################################################
# title       : bammergerun.sh                                                #
# description : This script executes SamTools merge on alignment BAM files in #
#               parallel.                                                     #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-12                                                    #
###############################################################################

# import chip-seq analysis libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $SCRIPT_DIR/chipseqlib.sh

# run_samtools_merge <output-bam> <log> <input-bam 1> <input-bam 2> [...]
# Wrapper function for SamTools merge
# Arguments
#   output-bam    : output BAM file
#   log           : SamTools merge log file
#   input-bam ... : BAM files to be merged
run_samtools_merge () {
  local stm_out_bam="$1"; shift
  local stm_log="$1"; shift
  local stm_in_bams=("$@")
  samtools merge $stm_out_bam "${stm_in_bams[@]}" >$stm_log 2>&1 
}

# get_stm_log <tissue>
# Locates the SamTools merge log file of a set
# Arguments
#   tissue : tissue name of set
# Output
#   samtools merge log file of set
get_stm_log () {
  local tissue="$1"
  local data_dir="$(get_data_dir $tissue)"
  local filestem="vdr-chip_${tissue}_merged_ngm_bt2"
  local filesuffix="_stm.log"
  local stm_log="$data_dir/${filestem}${filesuffix}"
  echo $stm_log
}

# samtools_merge_bams <tissue>
# Runs samtools merge on all replicate alignment BAM files of a set
# Arguments
#   tissue : tissue name of set
samtools_merge_bams () {
  local merged_bam="$(get_bam $tissue)"
  local stm_log="$(get_stm_log $tissue)"
  local replicate_bams=()
  # locate all replicate alignment BAM files of set
  for replicate in "${REPLICATES[@]}"; do
    local replicate_bam="$(get_bam $tissue $replicate)"
    replicate_bams+=("$replicate_bam")
  done
  run_samtools_merge $merged_bam $stm_log "${replicate_bams[@]}"
}

# main
# Driver function
main () {
  for tissue in "${TISSUES[@]}"; do
    samtools_merge_bams $tissue &
  done
  wait
}

main
