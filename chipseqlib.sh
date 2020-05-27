#!/usr/bin/env bash

###############################################################################
# title       : chipseqlib.sh                                                 #
# description : This library defines helper functions for a tissue-replicate  #
#               directory tree of ChIP-seq files.                             #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-06                                                    #
###############################################################################

# define directory structure
ROOT_DIR="/home/dennis/vdr/vdr-chip"
TISSUES=("colon" "crypt" "villi")
REPLICATES=("1" "2" "3" "4")

# get_data_dir <tissue> [<replicate>]
# Locates the data directory of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   if replicate specified     --> directory path of sample
#   if replicate not specified --> directory path of set
get_data_dir () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified --> output set directory
    local data_dir="$ROOT_DIR/$tissue"
  else
    # replicate specified --> output replicate directory
    local replicate="$2"
    local data_dir="$ROOT_DIR/$tissue/$replicate"
  fi
  echo $data_dir
}

# get_raw_fastq <tissue> <replicate> <direction>
# Locates a raw sequence FASTQ file of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
#   direction : sequencing direction of output FASTQ file [forward, reverse]
# Output
#   if direction = forward --> raw forward sequence FASTQ file of sample
#   if direction = reverse --> raw reverse sequence FASTQ file of sample
get_raw_fastq () {
  local tissue="$1"
  local replicate="$2"
  local direction="$3"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local filestem="vdr-chip_${tissue}_${replicate}"
  local filesuffix=".fastq.gz"
  if [ $direction = "forward" ]; then
    local fq_file="$data_dir/${filestem}_R1${filesuffix}"
  elif [ $direction = "reverse" ]; then
    local fq_file="$data_dir/${filestem}_R2${filesuffix}"
  else
    echo "ERROR: Invalid direction: $direction" >&2
    exit 1
  fi
  echo $fq_file
}

# run_fastqc <fastq> <output-dir>
# Wrapper function for FastQC
# Arguments
#   fastq       : input sequence FASTQ file
#   output-dir  : directory in which to write FastQC output
run_fastqc () {
  local fqc_fq="$1"
  local fqc_out_dir="$2"
  # FastQC can only output to working directory
  cd $fqc_out_dir
  fastqc $fqc_fq
}

# get_trimmed_fastq <tissue> <replicate> <direction>
# Locates a trimmed sequence FASTQ file of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
#   direction : sequencing direction of output FASTQ file [forward, reverse]
# Output
#   if direction = forward --> trimmed forward sequence FASTQ file of sample
#   if direction = reverse --> trimmed reverse sequence FASTQ file of sample
get_trimmed_fastq () {
  local tissue="$1"
  local replicate="$2"
  local direction="$3"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local filestem="vdr-chip_${tissue}_${replicate}"
  local filesuffix="_ngm.fastq.gz"
  if [ $direction = "forward" ]; then
    local fq_file="$data_dir/${filestem}_R1${filesuffix}"
  elif [ $direction = "reverse" ]; then
    local fq_file="$data_dir/${filestem}_R2${filesuffix}"
  else
    echo "ERROR: Invalid direction: $direction" >&2
    exit 1
  fi
  echo $fq_file
}

# get_bam <tissue> [<replicate>]
# Locates the alignment BAM file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   if replicate specified     --> alignment BAM file of sample
#   if replicate not specified --> merged alignment BAM file of set
get_bam () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="vdr-chip_${tissue}_merged_ngm"
    local filesuffix="_bt2_stm.bam"
  else
    # replicate specified
    local replicate="$2"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="vdr-chip_${tissue}_${replicate}_ngm"
    local filesuffix="_bt2.bam"
  fi
  local bam_file="$data_dir/${filestem}${filesuffix}"
  echo $bam_file
}

# get_bigwig <tissue> [<replicate>]
# Locates the track BW file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   if replicate specified     --> track BW file of sample
#   if replicate not specified --> merged track BW file of set
get_bigwig () {
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
  local filesuffix="_bc.bw"
  local bw_file="$data_dir/${filestem}${filesuffix}"
  echo $bw_file
}

# get_peakcentered_bed <tissue> [<replicate>]
# Locates the peak-centered BED file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   if replicate specified     --> peak-centered BED file of sample
#   if replicate not specified --> merged peak-centered BED file of set
get_peakcentered_bed () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="vdr-chip_${tissue}_merged_ngm_bt2_stm_m2_peaks"
  else
    # replicate specified
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="vdr-chip_${tissue}_${replicate}_ngm_bt2_m2_peaks"
  fi
  local filesuffix=".bed"
  local bed_file="$data_dir/${filestem}${filesuffix}"
  echo $bed_file
}

# get_summitcentered_bed <tissue> [<replicate>]
# Locates the summit-centered BED file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   if replicate specified     --> summit-centered BED file of sample
#   if replicate not specified --> merged summit-centered BED file of set
get_summitcentered_bed () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="vdr-chip_${tissue}_merged_ngm_bt2_stm_m2_summitpeaks"
  else
    # replicate specified
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="vdr-chip_${tissue}_${replicate}_ngm_bt2_m2_summitpeaks"
  fi
  local filesuffix=".bed"
  local bed_file="$data_dir/${filestem}${filesuffix}"
  echo $bed_file
}
