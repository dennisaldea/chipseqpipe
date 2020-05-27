#!/usr/bin/env bash

###############################################################################
# title       : bamcoveragerun.sh                                             #
# description : This script executes SamTools index on alignment BAM files in #
#               parallel, then executes BamCoverage to convert the indexed    #
#               alignment BAM files to track BigWig files.                    #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-12                                                    #
###############################################################################

# load libraries
BASH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $BASH_DIR/chipseqlib.sh

# BamCoverage options
BC_CORES=14

# run_samtools_index <bam> <output-dir> <log>
# Wrapper function for SamTools index
# Arguments
#   bam        : alignment BAM file to be indexed
#   output-dir : directory in which to write SamTools index output
#   log        : SamTools index log file
run_samtools_index () {
  local sti_bam="$1"
  local sti_out_dir="$2"
  local sti_log="$3"
  # SamTools index can only output to working directory
  cd $sti_out_dir
  samtools index $sti_bam >$sti_log 2>&1
}

# get_sti_log <tissue> [<replicate>]
# Locates the samtools index log file of a sample or set
# Output
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Returns
#   SamTools index log file of sample/set
get_sti_log () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="vdr-chip_${tissue}_merged_ngm_bt2_stm"
  else
    # replicate specified
    local replicate="$2"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="vdr-chip_${tissue}_${replicate}_ngm_bt2"
  fi
  local filesuffix="_sti.log"
  local sti_log="$data_dir/${filestem}${filesuffix}"
  echo $sti_log
}

# samtools_index_bam <tissue> [<replicate>]
# Runs samtools index on alignment BAM files of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate numbet of sample (optional)
samtools_index_bam () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local alignment_bam="$(get_bam $tissue)"
    local data_dir="$(get_data_dir $tissue)"
    local sti_log="$(get_sti_log $tissue)"
  else
    # replicate specified
    local replicate="$2"
    local alignment_bam="$(get_bam $tissue $replicate)"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local sti_log="$(get_sti_log $tissue $replicate)"
  fi
  run_samtools_index $alignment_bam $data_dir $sti_log
}

# samtools_index_traverse
# Initiates parallel execution of SamTools index on all alignment BAM files
samtools_index_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      samtools_index_bam $tissue $replicate &
    done
    samtools_index_bam $tissue &
  done
  wait
}

# run_bamcoverage <bam> <bw> <log>
# Wrapper function for BamCoverage
# Arguments
#   bam : alignment BAM file to be converted
#   bw  : output BigWig file
#   log : BamCoverage log file
run_bamcoverage () {
  local bc_bam="$1"
  local bc_out_bw="$2"
  local bc_log="$3"
  bamCoverage -p $BC_CORES -b $bc_bam -o $bc_out_bw >$bc_log 2>&1
}

# get_bc_log <tissue> [<replicate>]
# Locates the BamCoverage log file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   BamCoverage log file of sample/set
get_bc_log () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="vdr-chip_${tissue}_merged_ngm_bt2_stm"
  else
    # replicate specified
    local replicate="$2"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="vdr-chip_${tissue}_${replicate}_ngm_bt2"
  fi
  local filesuffix="_bc.log"
  local bc_log="$data_dir/${filestem}${filesuffix}"
  echo $bc_log
}

# bamcoverage_bam <tissue> [<replicate>]
# Runs BamCoverage on alignment BAM file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate numbet of sample (optional)
bamcoverage_bam () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local alignment_bam="$(get_bam $tissue)"
    local track_bw="$(get_bigwig $tissue)"
    local bc_log="$(get_bc_log $tissue)"
  else
    # replicate specified
    local replicate="$2"
    local alignment_bam="$(get_bam $tissue $replicate)"
    local track_bw="$(get_bigwig $tissue $replicate)"
    local bc_log="$(get_bc_log $tissue $replicate)"
  fi
  run_bamcoverage $alignment_bam $track_bw $bc_log
}

# bamcoverage_traverse
# Initiates execution of BamCoverage on all alignment BAM files
bamcoverage_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      bamcoverage_bam $tissue $replicate &
    done
    bamcoverage_bam $tissue &
  done
  wait
}

# main
# Driver function
main () {
  samtools_index_traverse
  bamcoverage_traverse
}

main
