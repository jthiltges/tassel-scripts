#!/bin/bash

set -e
module load tassel
module load bowtie2
set -x

# Options ##################################################
TASSEL_ARGS="-Xmx300g -Xms300g"
export JAVA_TOOL_OPTIONS+=" -XX:+UseParallelGC -XX:+UseNUMA -XX:+PrintCommandLineFlags -XX:+UnlockCommercialFeatures -XX:+FlightRecorder"
FASTQ=GBS/Chr9_10-20000000
KEYFILE=GBS/Pipeline_Testing_key.txt
ENZYME=ApeKI
BOWTIE_REF=../ref/data
CHR_START=1
CHR_END=1
############################################################

# Base output directory on timestamp
NOW=`date +%Y%m%d%H%M%S`
OUT=out.$NOW

# Increment a counter for each plugin we run
step=0

# Create output directories
cd `dirname $0`
mkdir $OUT $OUT/TagCounts $OUT/log

############################################################
# Convenience functions to call TASSEL and save logs
############################################################
# Call a TASSEL plugin
function tassel() {
  plugin=$1 # First argument is plugin
  shift
  opts=$*   # Following arguments are plugin options

  # Call TASSEL plugin
  tasselcmd $plugin \
    -${plugin} "${opts}" -endPlugin
}
# Run an arbitrary TASSEL pipeline command
function tasselcmd() {
  plugin=$1 # First argument is label
  shift
  opts=$*   # Following arguments are TASSEL arguments

  # Call TASSEL (no plugin)
  cmd $plugin \
    run_pipeline.pl ${TASSEL_ARGS} -fork1 \
    "${opts}" \
    -runfork1
}
# Run an arbitrary CLI command, logging to a file
function cmd() {
  label=$1 # First argument is label for logfile
  shift
  cmd=$*   # Following arguments is the command

  # Increment counter
  step=$[$step +1]

  # Zero-pad the number so the filenames sort nicely
  steptxt=`printf "%02d" $step`

  logfile=${OUT}/log/${steptxt}-${label}

  echo "Running $label at `date` " >> $logfile
  echo "cmd: $cmd"                 >> $logfile
  echo                             >> $logfile
  $cmd 2>&1 | tee -a $logfile
  echo "Finished $label at `date`" >> $logfile
}
############################################################

# Call the plugins #########################################
tassel FastqToTagCountPlugin \
  -i $FASTQ \
  -k $KEYFILE \
  -e $ENZYME \
  -o $OUT/TagCounts

tassel MergeMultipleTagCountPlugin \
  -i $OUT/TagCounts \
  -o $OUT/TagCount

# Reference
if true ; then
	tassel TagCountToFastqPlugin \
	  -i $OUT/TagCount \
	  -o $OUT/TagCount.fastq \
	  -c 2

	# Args from TasselPipelinePanGenomeAtlas.pdf
	cmd Align \
	  bowtie2 --threads=`nproc` \
	  -k 2 --very-sensitive-local \
	  -x $BOWTIE_REF \
	  -U $OUT/TagCount.fastq \
	  -S $OUT/TagCount.sam

	tassel SAMConverterPlugin \
	  -i $OUT/TagCount.sam \
	  -o $OUT/Pairs.topm
# UNEAK
else
	tassel UTagCountToTagPairPlugin \
	  -inputFile $OUT/TagCount \
	  -outputFile $OUT/TagPairs

	tassel UTagPairToTOPMPlugin \
	  -input $OUT/TagPairs \
	  -toBinary $OUT/Pairs.topm
fi
# End

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
  -sC $CHR_START \
  -eC $CHR_END

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

tasselcmd GenotypesToH5 \
  -h5 $OUT/Genotypes.h5 \
  -export $OUT/Genotypes.hmp.txt \
  -exportType HapmapDiploid

