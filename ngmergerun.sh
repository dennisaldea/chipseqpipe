#!/usr/bin/env bash

###############################################################################
# title       : ngmergerun.sh                                                 #
# description : This script executes NGmerge on raw sequence FASTQ files in   #
#               in parallel, then executes FastQC on the resulting trimmed    #
#               sequence FASTQ files in parallel.                             #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-07                                                    #
###############################################################################

# import chip-seq analysis libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $SCRIPT_DIR/chipseqlib.sh
NGM_EXE="/home/dennis/bin/NGmerge/NGmerge"

# run_ngmerge <forward-fq> <reverse-fq> <output-dir> <output-prefix> <log>
# Wrapper function for NGmerge
# Arguments
#   forward-fq    : untrimmed forward sequence FASTQ file
#   reverse-fq    : untrimmed reverse sequence FASTQ file
#   output-dir    : directory in which to write NGmerge output
#   output-prefix : prefix used for NGmerge output files
#   log           : NGmerge log file
run_ngmerge () {
  local ngm_for_fq="$1"
  local ngm_rev_fq="$2"
  local ngm_out_dir="$3"
  local ngm_out_pre="$4"
  local ngm_log="$5"
  # NGmerge can only output to working directory
  cd $ngm_out_dir
  $NGM_EXE -v -a -1 $ngm_for_fq -2 $ngm_rev_fq -z -o $ngm_out_pre >$ngm_log \
    2>&1
}

# get_ngm_log <tissue> <replicate>
# Locates the NGmerge log file of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
# Output
#   NGmerge log file of sample
get_ngm_log () {
  local tissue="$1"
  local replicate="$2"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local filestem="vdr-chip_${tissue}_${replicate}"
  local filesuffix="_ngm.log"
  local ngm_log="$data_dir/${filestem}${filesuffix}"
  echo $ngm_log
}
# ngmerge_raw_fastqs <tissue> <replicate>
# Runs NGmerge on raw sequence FASTQ files of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
ngmerge_raw_fastqs () {
  local tissue="$1"
  local replicate="$2"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local for_fq="$(get_raw_fastq $tissue $replicate forward)"
  local rev_fq="$(get_raw_fastq $tissue $replicate reverse)"
  local ngm_prefix="$(echo $(basename $for_fq) | sed -e 's/_R[1-2].*$//')"
  local ngm_log="$(get_ngm_log $tissue $replicate)"
  run_ngmerge $for_fq $rev_fq $data_dir $ngm_prefix $ngm_log
  # Given an output directory <DIR> and an output prefix <PRE>, NGmerge
  # generates a forward trimmed FASTQ file <DIR>/<PRE>_1.fastq.gz and a reverse
  # trimmed FASTQ file <DIR>/<PRE>_2.fastq.gz . This rename command renames the
  # forward trimmed FASTQ to <DIR>/<PRE>_R1_ngm.fastq.gz and renames the
  # reverse trimmed FASTQ to <DIR>/<PRE>_R2_ngm.fastq.gz .
  rename 's/(?<=_)([12])(?=\.fastq\.gz$)/R$1_ngm/' ${ngm_prefix}*
}

# ngmerge_traverse
# Initiates parallel execution of NGmerge on all raw sequence FASTQ files
ngmerge_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      ngmerge_raw_fastqs $tissue $replicate &
    done
  done
  wait
}

# fastqc_trimmed_fastqs <tissue> <replicate>
# Runs FastQC on trimmed sequence FASTQ files of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate numbet of sample
fastqc_trimmed_fastqs () {
  local tissue="$1"
  local replicate="$2"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local for_fq="$(get_trimmed_fastq $tissue $replicate forward)"
  run_fastqc $for_fq $data_dir &
  local rev_fq="$(get_trimmed_fastq $tissue $replicate reverse)"
  run_fastqc $rev_fq $data_dir &
}

# ngmfastqc_traverse
# Initiates parallel execution of FastQC on all trimmed sequence FASTQ files
ngmfastqc_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      fastqc_trimmed_fastqs $tissue $replicate &
    done
  done
  wait
}

# main
# Driver function
main () {
  ngmerge_traverse
  ngmfastqc_traverse
}

main
