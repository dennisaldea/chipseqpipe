#!/usr/bin/env bash

###############################################################################
# title       : bowtie2run.sh                                                 #
# description : This script executes Bowtie2 on trimmed sequence FASTQ files, #
#               then converts the resulting alignment SAM files to alignment  #
#               BAM files.                                                    #
# author      : Dennis Aldea <dennis.aldea@rutgers.edu>                       #
# license     : MIT <https://opensource.org/licenses/MIT>                     #
# date        : 2020-05-06                                                    #
###############################################################################

# import chip-seq analysis libraries
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd )"
source $SCRIPT_DIR/chipseqlib.sh
HG19_FA="/mnt/input/ref/Homo_sapiens/UCSC/hg19/Sequence/Bowtie2Index/genome"
MM9_FA="/mnt/input/ref/Mus_musculus/UCSC/mm9/Sequence/Bowtie2Index/genome"

# Bowtie2 parameters
BT2_CORES=14
BT2_PRESET="--very-sensitive"
GENOME="mm9"
ST_KEEP_SAM=false

# run_bowtie2 <forward-fq> <reverse-fq> <preset> <genome-fa> <output-sam> <log>
# Wrapper function for Bowtie2
# Arguments
#   forward-fq : trimmed forward sequence FASTQ file
#   reverse-fq : trimmed reverse sequence FASTQ file
#   preset     : Bowtie2 preset option
#   genome-fa  : alignment genome FA path
#   output-sam : alignments SAM file output
#   log        : Bowtie2 log file
run_bowtie2 () {
  local bt2_for_fq="$1"
  local bt2_rev_fq="$2"
  local bt2_preset="$3"
  local bt2_fa="$4"
  local bt2_out_sam="$5"
  local bt2_log="$6"
  bowtie2 $bt2_preset -p $BT2_CORES -x $bt2_fa -1 $bt2_for_fq -2 $bt2_rev_fq \
    -S $bt2_out_sam >$bt2_log 2>&1
}

# get_genome_fa <genome>
# Locates the FA path of a Bowtie2 genome
# Arguments
#   genome : genome name [hg19, mm9]
# Output
#   FA path of genome
get_genome_fa () {
  local genome="$1"
  if [ $genome = "hg19" ]; then
    local bt2_fa=$HG19_FA
  elif [ $genome = "mm9" ]; then
    local bt2_fa=$MM9_FA
  else
    echo "ERROR: Invalid genome: $genome" >&2
    exit 1
  fi
  echo $bt2_fa
}

# get_sam <tissue> <replicate>
# Locates the alignment SAM file of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
# Output
#   alignments SAM file of sample
get_sam () {
  local tissue="$1"
  local replicate="$2"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local filestem="vdr-chip_${tissue}_${replicate}_ngm"
  local filesuffix="_bt2.sam"
  local sam_file="$data_dir/${filestem}${filesuffix}"
  echo $sam_file
}

# get_bt2_log <tissue> <replicate>
# Locates the Bowtie2 log file of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
# Output
#   Bowtie2 log file of sample
get_bt2_log () {
  local tissue="$1"
  local replicate="$2"
  local data_dir="$(get_data_dir $tissue $replicate)"
  local filestem="vdr-chip_${tissue}_${replicate}_ngm"
  local filesuffix="_bt2.log"
  local bt2_log="$data_dir/${filestem}${filesuffix}"
  echo $bt2_log
}

# bowtie2_trimmed_fastqs <tissue> <replicate>
# Runs Bowtie2 on trimmed sequence FASTQ files of a sample
# Arguments
#   tissue    : tissue name of sample
#   replicate : replicate number of sample
bowtie2_trimmed_fastqs () {
  local tissue="$1"
  local replicate="$2"
  local for_fq="$(get_trimmed_fastq $tissue $replicate forward)"
  local rev_fq="$(get_trimmed_fastq $tissue $replicate reverse)"
  local bt2_preset="$BT2_PRESET"
  local bt2_fa="$(get_genome_fa $GENOME)"
  local bt2_out_sam="$(get_sam $tissue $replicate)"
  local bt2_log="$(get_bt2_log $tissue $replicate)"
  run_bowtie2 $for_fq $rev_fq $bt2_preset $bt2_fa $bt2_out_sam $bt2_log
  # Bowtie2 generates an alignment SAM text file. Further processing requires
  # the alignment SAM text file to be converted to an alignment BAM binary
  # file. Since the binary BAM file requires less disk space, it is usually
  # desirable to delete the SAM file once the BAM file is generated. This is
  # the default behavior unless ST_KEEP_SAM is true.
  local alignments_bam="$(get_bam $tissue $replicate)"
  samtools view -bSu $bt2_out_sam | samtools sort - ${alignments_bam%.bam}
  if [ "$ST_KEEP_SAM" != true ]; then
    rm $bt2_out_sam
  fi
}

# main
# Driver function
main () {
  for tissue in "${TISSUES[@]}"; do
    for replicate in "${REPLICATES[@]}"; do
      bowtie2_trimmed_fastqs $tissue $replicate
    done
  done
}

main
