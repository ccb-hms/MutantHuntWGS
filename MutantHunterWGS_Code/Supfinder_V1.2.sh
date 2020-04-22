#!/bin/bash

#Enable user input

while getopts m:n:g:f:r:s:o: option
do
 case "${option}"
 in
 m) FASTQ1=${OPTARG};;
 n) FASTQ2=${OPTARG};;
 g) GENOME=${OPTARG};;
 f) GENOME_FASTA=${OPTARG};;
 r) READ_TYPE=${OPTARG};;
 s) SCORE=${OPTARG};;
 o) OUTPUT_FILE=${OPTARG};;
 esac
done

echo "$FASTQ1"
echo "$FASTQ2"
echo "$GENOME"
echo "$GENOME_FASTA"
echo "$READ_TYPE"
echo "$SCORE"
echo "$OUTPUT_FILE"

#Make Output directory

mkdir "$OUTPUT_FILE"

cd "$OUTPUT_FILE"


#Allow user to specify read type and input files correctly to bowtie2

EXTENSION_1=_R1.fastq
EXTENSION_2=_R2.fastq

case "$READ_TYPE" in
	paired)
		a="-1 $FASTQ1$EXTENSION_1 -2 $FASTQ1$EXTENSION_2"
		echo $a
		;;
	single)
		a="-U $FASTQ1.fastq"
		echo $a 
		;;
	*)
	echo 'incorrect read type for file 1'
	;;
esac


case "$READ_TYPE" in
	paired)
		b="-1 $FASTQ2$EXTENSION_1 -2 $FASTQ2$EXTENSION_2"
		echo $b
		;;
	single)
		b="-U $FASTQ2.fastq"
		echo $b 
		;;
	*)
	echo 'incorrect read type for file 2'
	;;
esac

#Loop to process the two files starts here

names="$FASTQ1 $FASTQ2"

for i in $names
do
	echo "Running $i file now"
	
if [ "$i" = "$FASTQ1" ]
then
	j="$a"
elif [ "$i" = "$FASTQ2" ]
then
	j="$b"
fi

echo "$j"

#Using this command to get only the file name and lose the path
k=`echo "$i" | awk -F "/" '{print $(NF)}'` 


##Run Bowtie 2 and convert output to BAM with Samtools

bowtie2 --no-unal \
		-q -k2 \
		-p16 \
		-x "$GENOME" \
		"$j" \
		2> "$OUTPUT_FILE"/"$k".bowtie.txt \
		| samtools view - -bS > "$OUTPUT_FILE"/"$k".unsorted.bam

##Sort BAM with Samtools
		
samtools sort "$OUTPUT_FILE"/"$k".unsorted.bam -o "$OUTPUT_FILE"/"$k".sorted.bam

##Index BAM with Samtools

samtools index "$OUTPUT_FILE"/"$k".sorted.bam

#remove unsorted BAM

#rm "$OUTPUT_FILE"/"$k".unsorted.bam

#The first step is to use the SAMtools mpileup command to calculate the genotype likelihoods supported by the aligned reads in our sample

samtools mpileup -g -f "$GENOME_FASTA".fa "$OUTPUT_FILE"/"$k".sorted.bam -o "$OUTPUT_FILE"/"$k".sim_variants.bcf

#-g: directs SAMtools to output genotype likelihoods in the binary call format (BCF). This is a compressed binary format.
#-f: directs SAMtools to use the specified reference genome. A reference genome must be specified.

#The second step is to use bcftools:

bcftools call -c -v --ploidy 1 "$OUTPUT_FILE"/"$k".sim_variants.bcf > "$OUTPUT_FILE"/"$k".sim_variants.vcf

#The bcftools call command uses the genotype likelihoods generated from the previous step to call SNPs and indels, and outputs the all identified variants in the variant call format (VFC), the file format created for the 1000 Genomes Project, and now widely used to represent genomic variants.

done


#Using this command to get only the file name and lose the path
Mutant=`echo $FASTQ1 | awk -F "/" '{print $(NF)}'` 
Wild_type=`echo $FASTQ2 | awk -F "/" '{print $(NF)}'`

#Compare variations in the two files

vcftools --vcf "$Mutant".sim_variants.vcf --diff "$Wild_type".sim_variants.vcf --diff-site --out "$Mutant".vs."$Wild_type".txt

#Here I am using awk to find all of the values in the file SUP_22.vs.WT_22.diff.sites_in_files where Sup22 snps are not the same as Wt22 snps. Once these values are found they are piped back into awk and we select rows the have no value in the third column (Wt22 snps) it seems like this should have already been done with the first command, but there are still some that are not exact matches that were not removed. The rest of the second awk command prints column 1 (chr), column 2 (snp locations), and column 2 + 1 (snp location plus 1 so that BEDtools likes the file.

awk -F "\t" '$2 != $3' "$Mutant".vs."$Wild_type".txt.diff.sites_in_files | awk -F "\t" '$3 == "." {print $1 "\t" $2 "\t" $2 + 1}' > "$Mutant".vs."$Wild_type".diff.txt



################################################################################

##These next two steps are just to generate some subsetted files so we have them to look at

#Here I am using awk to remove the third column so that I can make files for use with the grep command below

awk -F "\t" '$2 != $3' "$Mutant".vs."$Wild_type".txt.diff.sites_in_files | awk -F "\t" '$3 == "." {print $1 "\t" $2}' > "$Mutant".vs."$Wild_type".diff.sites.for.grep.txt

grep -f "$Mutant".vs."$Wild_type".diff.sites.for.grep.txt "$Mutant".sim_variants.vcf > "$Mutant".dif.vcf

#Get VCF header information so we can add it to the new file allowing it to be viewed in IGV
head -n 48 "$Mutant".sim_variants.vcf > VCF.header.info.txt

awk ' $6 >= '$SCORE' {print}' "$Mutant".dif.vcf > "$Mutant".dif.sub.vcf

cat VCF.header.info.txt "$Mutant".dif.vcf > "$Mutant".diff.vcf

cat VCF.header.info.txt "$Mutant".dif.sub.vcf > "$Mutant".diff.sub.vcf

rm "$Mutant".dif.vcf "$Mutant".dif.sub.vcf

################################################################################



#Use SNPeff to find out some more information about these SNPs like the amino acid change in the resulting protein

java -Xmx4G -jar /MutantHunter/snpEff/snpEff.jar ann -v Saccharomyces_cerevisiae "$Mutant".diff.sub.vcf > snpeff.ann.txt


awk -F '[\t|]' 'NR > 5 {print $1 "\t" $2 "\t"$3 "\t"$4 "\t"$5 "\t"$6 "\t"$9 "\t"$10 "\t" $11 "\t" $12 $17 "\t" $18 "\t"  "\t" $8}' snpeff.ann.txt > snpeff.ann.clean.txt



##Run SIFT

java -Xmx4G -jar /MutantHunter/SIFT4G_Annotator.jar -c -i "$Mutant".diff.sub.vcf -d /MutantHunter/EF4.74 -r SIFT_out



exit




