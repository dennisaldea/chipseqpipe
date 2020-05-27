#!/usr/bin/env bash

###############################################################################
# title       : siteprobw.sh                                                  #
# description : This script executes SiteproBW to plot track BigWig files     #
#               against peakset BED files in parallel.                        #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-19                                                    #
###############################################################################

# import chip-seq analysis libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $SCRIPT_DIR/chipseqlib.sh

# run_siteprobw <output-dir> <name> <log> <bw> <bed>[...]
# Wrapper function for SiteproBW
# Arguments
#   output-dir : directory in which to write SiteproBW output
#   name       : SiteproBW name to prefixed for output files
#   log        : SiteproBW log file
#   bw         : track BigWig file to be plotted
#   bed        : peakset BED file(s) to be plotted
run_siteprobw () {
  local sp_out_dir="$1"; shift
  local sp_name="$1"; shift
  local sp_log="$1"; shift
  local sp_in_bw="$1"; shift
  local sp_in_beds=("$@")
  local num_beds=${#sp_in_beds[@]}
  # append '-b' flag before every bed file
  for (( i=0; i<$num_beds; i++ )); do
    sp_in_beds[i]="-b ${sp_in_beds[i]}"
  done
  # siteproBW can only output to working directory
  cd $sp_out_dir
  siteproBW --name $sp_name -w $sp_in_bw ${sp_in_beds[@]} >$sp_log 2>&1
}

# get_sp_name <tissue> <sample> <centering>
# Determines the SiteproBW name of a specified sample or merging
# Arguments
#   tissue    : tissue name of sample or merging
#   sample    : replicate number of sample OR type of merging [all, merge]
#   centering : centering of peakset BED files [peakcentered, summitcentered]
# Output
#   SiteproBW name of sample or merging
get_sp_name () {
  local tissue="$1"
  local sample="$2"
  local centering="$3"
  if [ $centering = "peakcentered" ]; then
    local centering_suffix="peaks"
  elif [ $centering = "summitcentered" ]; then
    local centering_suffix="summitpeaks"
  else
    echo "ERROR: Invalid centering: $centering" >&2
    exit 1
  fi
  local sp_name="vdr-chip_${tissue}_${sample}_${centering_suffix}_sp"
  echo $sp_name
}

# makespplots <tissue> <centering>
# Runs SiteproBW in parallel on track BigWig and specified BED files of a set
# Arguments
#   tissue    : tissue name of set
#   centering : centering of peakset BED files [peakcentered, summitcentered]
makespplots () {
  local tissue="$1"
  local centering="$2"
  local replicate_beds=()
  # for each replicate: plot replicate BigWig versus replicate BED
  for replicate in "${REPLICATES[@]}"; do
    # locate replicate BED files
    local replicate_dir="$(get_data_dir $tissue $replicate)"
    local sp_name="$(get_sp_name $tissue $replicate $centering)"
    local sp_log="$replicate_dir/${sp_name}.log"
    local replicate_bw="$(get_bigwig $tissue $replicate)"
    if [ $centering = "peakcentered" ]; then
      local replicate_bed="$(get_peakcentered_bed $tissue $replicate)"
    elif [ $centering = "summitcentered" ]; then
      local replicate_bed="$(get_summitcentered_bed $tissue $replicate)"
    else
      echo "ERROR: Invalid centering: $centering" >&2
      exit 1
    fi
    run_siteprobw $replicate_dir $sp_name $sp_log $replicate_bw $replicate_bed
    # add peakset BED to replicate BED files array
    replicate_beds+=("$replicate_bed")
  done
  local tissue_dir="$(get_data_dir $tissue)"
  # plot merged BigWig versus replicate BED
  local sp_name="$(get_sp_name $tissue all $centering)"
  local sp_log="$tissue_dir/${sp_name}.log"
  local merged_bw="$(get_bigwig $tissue)"
  run_siteprobw $tissue_dir $sp_name $sp_log $merged_bw $replicate_beds
  # plot merged BigWig versus merged BED
  local sp_name="$(get_sp_name $tissue merge $centering)"
  local sp_log="$tissue_dir/${sp_name}.log"
  if [ $centering = "peakcentered" ]; then
    local merged_bed="$(get_peakcentered_bed $tissue)"
  elif [ $centering = "summitcentered" ]; then
    local merged_bed="$(get_summitcentered_bed $tissue)"
  else
    echo "ERROR: Invalid centering: $centering" >&2
    exit 1
  fi
  run_siteprobw $tissue_dir $sp_name $sp_log $merged_bw $merged_bed
}

# makespplots_traverse <centering>
# Initiates parallel plotting of track BigWig against specified BED files
# Arguments
#   centering : centering of peakset BED files [peakcentered, summitcentered]
makespplots_traverse () {
  local centering="$1"
  for tissue in "${TISSUES[@]}"; do
    makespplots $tissue $centering &
  done
  wait
}

# main
# Driver function
main () {
  makespplots_traverse peakcentered
  makespplots_traverse summitcentered
}

main
