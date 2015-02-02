#!/bin/bash

set -e
module load tassel
set -x

# Options ########################################
TASSEL_ARGS="-Xmx120g -Xms120g"
FASTQ=GBS/Chr9_10-20000000
KEYFILE=GBS/Pipeline_Testing_key.txt
ENZYME=ApeKI
##################################################

# Base output directory on timestamp
NOW=`date +%Y%m%d%H%M%S`
OUT=out.$NOW

# Increment a counter for each plugin we run
step=0

# Create output directories
cd `dirname $0`
mkdir $OUT $OUT/TagCounts $OUT/log

# Convenience function to call TASSEL and save logs
function tassel() {
  plugin=$1 # First argument is plugin
  shift
  opts=$*   # Following arguments are plugin options

  # Increment counter
  step=$[$step +1]

  echo "Running ${step}-${plugin}"

  logfile=${OUT}/log/${step}-${plugin}

  echo "Started $plugin at `date`" >> $logfile

  # Call TASSEL
  run_pipeline.pl ${TASSEL_ARGS} -fork1 \
    -${plugin} ${opts} \
    -endPlugin -runfork1 2>&1 | tee -a $logfile

  echo "Finished $plugin at `date`" >> $logfile
}

# Call the plugins ###############################
tassel FastqToTagCountPlugin \
  -i $FASTQ \
  -k $KEYFILE \
  -e $ENZYME \
  -o $OUT/TagCounts

tassel MergeMultipleTagCountPlugin \
  -i $OUT/TagCounts \
  -o $OUT/TagCount

tassel UTagCountToTagPairPlugin \
  -inputFile $OUT/TagCount \
  -outputFile $OUT/TagPairs

tassel UTagPairToTOPMPlugin \
  -input $OUT/TagPairs \
  -toBinary $OUT/Pairs.topm

tassel SeqToTBTHDF5Plugin \
  -i $FASTQ \
  -k $KEYFILE \
  -e $ENZYME \
  -o $OUT/TagsByTaxa.h5 \
  -L $OUT/TagsByTaxa.log \
  -m $OUT/Pairs.topm

tassel ModifyTBTHDF5Plugin \
  -o $OUT/TagsByTaxa.h5 \
  -p $OUT/TagsByTaxaPivot.h5

tassel DiscoverySNPCallerPlugin \
  -i $OUT/TagsByTaxaPivot.h5 \
  -m $OUT/Pairs.topm \
  -o $OUT/Discovery.topm \
  -log $OUT/Discovery.topm.log \
  -sC 1 \
  -eC 1

tassel BinaryToTextPlugin \
  -i $OUT/Discovery.topm \
  -o $OUT/Discovery.topm.txt \
  -t TOPM

tassel ProductionSNPCallerPlugin \
  -i $FASTQ \
  -k $KEYFILE \
  -e $ENZYME \
  -m $OUT/Discovery.topm \
  -o $OUT/Genotypes.h5

