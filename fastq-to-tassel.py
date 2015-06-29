#!/usr/bin/env python
# vim: tabstop=8 expandtab shiftwidth=4 softtabstop=4

'''
Convert demuxed, indexed FASTQ to Cornell TASSEL compatible format:
  1) Prepend index barcode from header onto the front of the sequence.
  2) Optionally include an enzyme.
'''

import sys
import fileinput
import argparse
from Bio import SeqIO
from Bio.Seq import Seq
from Bio.SeqRecord import SeqRecord

##################################################
def parse_args():
    '''Parse command-line arguments'''
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--enzyme', help='Enzyme to insert after barcode')
    parser.add_argument('--output', '-o', help='Output file',
                        type=argparse.FileType('w'), default=sys.stdout)
    parser.add_argument('files', nargs='*', help='Input files', default="-")

    return parser.parse_args()

def convert_record(record, enzyme=None):
    '''Convert record to TASSEL format'''
    # Get the barcode from the end of the FASTQ header
    barcode = record.description.split(':')[-1]

    # If an enzyme is specified, add it after the barcode
    if enzyme:
        barcode += enzyme

    # Make a SeqRecord out of the barcode
    bc_seq = SeqRecord(Seq(barcode))
    bc_seq.letter_annotations['phred_quality'] = [0] * len(barcode)

    # Prepend the barcode onto the insert
    out_rec = bc_seq + record

    # And copy over the id and description fields
    out_rec.id = record.id
    out_rec.description = record.description

    return out_rec

def main():
    '''command-line interface'''
    args = parse_args()

    for record in SeqIO.parse(fileinput.input(args.files), "fastq"):
        out_rec = convert_record(record, args.enzyme)
        SeqIO.write(out_rec, args.output, "fastq")

if __name__ == '__main__':
    main()

