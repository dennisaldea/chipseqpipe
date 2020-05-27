#!/usr/bin/env bash

###############################################################################
# title       : macs2run.sh                                                   #
# description : This script executes MACS2 callpeak on alignment BAM files in #
#               parallel, then generates peak-centered and summit-centered    #
#               BED files from the resulting MACS2 narrowpeak files in        #
#               parallel.                                                     #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-18                                                    #
###############################################################################

# import chip-seq analysis libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $SCRIPT_DIR/chipseqlib.sh
M2_EXE="/home/dennis/.pyenv/shims/macs2"

# MACS2 callpeak options
GENOME="mm9"

# run_macs2_callpeak <bam> <genome> <output-dir> <name> <log>
# Wrapper function for MACS2 callpeak
# Arguments
#   bam        : alignment BAM (paired-end) file to be processed
#   genome     : MACS2 callpeak effective genome size option
#   output-dir : directory in which to write MACS2 callpeak output
#   name       : MACS2 callpeak name string prefixed to output files
#   log        : MACS2 callpeak log file
run_macs2_callpeak () {
  local m2_bam="$1"
  local m2_genome="$2"
  local m2_out_dir="$3"
  local m2_name="$4"
  local m2_log="$5"
  $M2_EXE callpeak -t $m2_bam -f BAMPE -g $m2_genome -B --outdir $m2_out_dir \
    -n $m2_name >$m2_log 2>&1
}

# get_m2_genome <genome>
# Determines the MACS2 callpeak effective genome size option of a genome
# Arguments
#   genome : genome name [hg19, mm9]
# Output
#   MACS2 callpeak effective genome size option of genome
get_m2_genome () {
  local genome="$1"
  if [ $genome = "hg19" ]; then
    local m2_genome="hs"
  elif [ $genome = "mm9" ]; then
    local m2_genome="mm"
  else
    echo "ERROR: Invalid genome: $genome" >&2
    exit 1
  fi
  echo $m2_genome
}

# get_m2_log <tissue> [<replicate>]
# Locates the MACS2 callpeak log file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   MACS2 callpeaks log file of sample/set
get_m2_log () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="vdr-chip_${tissue}_merged_ngm_bt2_stm_bc"
  else
    # replicate specified
    local replicate="$2"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="vdr-chip_${tissue}_${replicate}_ngm_bt2_bc"
  fi
  local filesuffix="_m2.log"
  local m2_log="$data_dir/${filestem}${filesuffix}"
  echo $m2_log
}

# get_m2_name <tissue> [<replicate>]
# Determines the MACS2 callpeak name of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   MACS2 callpeak name of sample/set
get_m2_name () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local alignment_bam="$(get_bam $tissue)"
  else
    # replicate specified
    local alignment_bam="$(get_bam $tissue $replicate)"
  fi
  local bam_basename="$(basename $alignment_bam)"
  local m2_name="${bam_basename%.bam}_m2"
  echo $m2_name
}

# macs2_callpeaks_bam <tissue> [<replicate>]
# Runs MACS2 callpeaks on alignment BAM file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate numbet of sample (optional)
macs2_callpeaks_bam () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local alignment_bam="$(get_bam $tissue)"
    local data_dir="$(get_data_dir $tissue)"
    local m2_name="$(get_m2_name $tissue)"
    local m2_log="$(get_m2_log $tissue)"
  else
    # replicate specified
    local replicate="$2"
    local alignment_bam="$(get_bam $tissue $replicate)"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local m2_name="$(get_m2_name $tissue $replicate)"
    local m2_log="$(get_m2_log $tissue $replicate)"
  fi
  local m2_genome="$(get_m2_genome $GENOME)"
  run_macs2_callpeak $alignment_bam $m2_genome $data_dir $m2_name $m2_log
}

# m2_callpeaks_traverse
# Initiates parallel execution of MACS2 callpeak on all alignment BAM files
m2_callpeaks_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      macs2_callpeaks_bam $tissue $replicate &
    done
    macs2_callpeaks_bam $tissue &
  done
  wait
}

# np_to_peakcenteredbed <narrowpeak> <output-bed>
# Makes peak-centered BED file from MACS2 narrowpeak file
# Arguments
#   narrowpeak : MACS2 narrowpeak file
#   output-bed : output peak-centered BED file
np_to_peakcenteredbed () {
  local m2_np="$1"
  local peakcentered_bed="$2"
  awk '{
    chromosome = $1; start = $2; end = $3;
    print chromosome "\t" start "\t" end
  }' $m2_np > $peakcentered_bed
}

# get_narrowpeak <tissue> [<replicate>]
# Locates the MACS2 narrowpeak file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
# Output
#   if replicate specified     --> MACS2 narrowpeak file of sample
#   if replicate not specified --> MACS2 narrowpeak file of set
get_narrowpeak () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local data_dir="$(get_data_dir $tissue)"
    local filestem="$(get_m2_name $tissue)"
  else
    # replicate specified
    local replicate="$2"
    local data_dir="$(get_data_dir $tissue $replicate)"
    local filestem="$(get_m2_name $tissue $replicate)"
  fi
  local filesuffix="_peaks.narrowPeak"
  local np_file="$data_dir/${filestem}${filesuffix}"
  echo $np_file
}

# make_peakcentered_bed <tissue> [<replicate>]
# Runs np_to_peakcenteredbed on MACS2 narrowpeak file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
make_peakcentered_bed () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local m2_np="$(get_narrowpeak $tissue)"
    local peakcentered_bed="$(get_peakcentered_bed $tissue)"
  else
    # replicate specified
    local replicate="$2"
    local m2_np="$(get_narrowpeak $tissue $replicate)"
    local peakcentered_bed="$(get_peakcentered_bed $tissue $replicate)"
  fi
  np_to_peakcenteredbed $m2_np $peakcentered_bed
}

# makepeakcenteredbed_traverse
# Initiates parallel execution of make_peakcentered_bed on narrowpeak files
makepeakcenteredbed_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      make_peakcentered_bed $tissue $replicate &
    done
    make_peakcentered_bed $tissue &
  done
  wait
}

# np_to_summitcenteredbed <narrowpeak> <output-bed>
# Generates summit-centered BED file from MACS2 narrowpeak file
# Arguments
#   narrowpeak : MACS2 narrowpeak file
#   output-bed : output summit-centered BED file
np_to_summitcenteredbed () {
  local m2_np="$1"
  local summitcentered_bed="$2"
  awk '{
    chromosome = $1; start = $2; end = $3;
    summit = start + $10;
    center = start + int( (end - start) / 2 );
    shift = summit - center;
    shifted_start = start + shift; shifted_end = end + shift;
    print chromosome "\t" shifted_start "\t" shifted_end
  }' $m2_np > $summitcentered_bed
}

# make_summitcentered_bed <tissue> [<replicate>]
# Runs summitcenter_bed on peak-centered BED file of a sample or set
# Arguments
#   tissue    : tissue name of sample/set
#   replicate : replicate number of sample (optional)
make_summitcentered_bed () {
  local tissue="$1"
  if [ $# -lt 2 ]; then
    # replicate not specified
    local m2_np="$(get_narrowpeak $tissue)"
    local summitcentered_bed="$(get_summitcentered_bed $tissue)"
  else
    # replicate specified
    local replicate="$2"
    local m2_np="$(get_narrowpeak $tissue $replicate)"
    local summitcentered_bed="$(get_summitcentered_bed $tissue $replicate)"
  fi
  np_to_summitcenteredbed $m2_np $summitcentered_bed
}

# makesummitcenteredbed_traverse
# Initiates parallel execution of make_summitcentered_bed on BED files
makesummitcenteredbed_traverse () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      make_summitcentered_bed $tissue $replicate &
    done
    make_summitcentered_bed $tissue &
  done
  wait
}

# main
# Driver function
main () {
  m2_callpeaks_traverse
  makepeakcenteredbed_traverse
  makesummitcenteredbed_traverse
}

main
