#!/bin/bash
#SBATCH --partition=short
#SBATCH -c 16
#SBATCH --time=0-5:00:00
#SBATCH --mem=16G
#SBATCH --mail-type=ALL
#SBATCH --mail-user=<YOURNAMEHERE>@hms.harvard.edu



module load gcc/6.2.0 bowtie2/2.2.9 samtools/1.3.1  bcftools/1.3.1 vcftools/0.1.15 java/jdk-1.8u112 snpEff/4.3g qualimap/2.2.1 bedtools/2.27.1
/n/data1/hms/ccb/projects/yeast_wgs/MutantHuntWGS/Code/MutantHuntWGS_o2.sh \
    -n sample-7 \
    -g /n/data1/hms/ccb/projects/yeast_wgs/MutantHuntWGS/S_cerevisiae_Bowtie2_Index_and_FASTA/genome \
    -f /n/data1/hms/ccb/projects/yeast_wgs/MutantHuntWGS/S_cerevisiae_Bowtie2_Index_and_FASTA/genome.fa \
    -r single \
    -s 10 \
    -p /n/data1/hms/ccb/projects/yeast_wgs/MutantHuntWGS/S_cerevisiae_Bowtie2_Index_and_FASTA/ploidy_n1.txt \
    -d /n/data1/hms/ccb/projects/yeast_wgs/Analysis_Directory/FASTQ \
    -o /n/data1/hms/ccb/projects/yeast_wgs/Analysis_Directory/test_cov_qualimap_output \
    -a YES \
    -t 16

date
