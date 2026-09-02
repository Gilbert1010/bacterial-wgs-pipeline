nextflow.enable.dsl=2

params.outdir = 'results'

process FASTQC {

	conda '/home/gilbert/miniconda3/envs/ngs-qc'
	
	publishDir "${params.outdir}/qc/raw", mode: 'copy'

	input:
	tuple val(sample_id), path(r1), path(r2)

	output:
	path "*.html"
	path "*.zip"

	script:
	"""
	fastqc $r1 $r2
	"""
}

process TRIMMOMATIC {

	conda '/home/gilbert/miniconda3/envs/ngs-qc'

	publishDir "${params.outdir}/trimmed", mode: 'copy'

	input:
	tuple val(sample_id), path(r1), path(r2)

	output:
	tuple val(sample_id), path("*_R1_paired.fastq.gz"), path("*_R2_paired.fastq.gz")

	script:
	"""
	trimmomatic PE \
	$r1 \
	$r2 \
	${sample_id}_R1_paired.fastq.gz \
	${sample_id}_R1_unpaired.fastq.gz \
	${sample_id}_R2_paired.fastq.gz \
	${sample_id}_R2_unpaired.fastq.gz \
	SLIDINGWINDOW:4:20 \
	LEADING:3 \
	TRAILING:3 \
	MINLEN:36
	"""
}

process FASTQC_TRIMMED {

    
	conda '/home/gilbert/miniconda3/envs/ngs-qc'

	publishDir "${params.outdir}/qc/trimmed", mode: 'copy'

	input:
	tuple val(sample_id), path(r1), path(r2)

	output:
	path "*.html"
	path "*.zip"

	script:
	"""
	fastqc $r1 $r2
	"""
}

process BWA_INDEX {

	conda '/home/gilbert/miniconda3/envs/ngs-align'

	publishDir "${params.outdir}/reference", mode: 'copy'

	input:
	path reference

	output:
	path "reference"

	script:
	"""
	mkdir reference
	cp $reference reference/reference.fas
	cd reference
	bwa index reference.fas
	"""

}

process BWA_MEM {

	conda '/home/gilbert/miniconda3/envs/ngs-align'
	
	publishDir "${params.outdir}/mapping", mode: 'copy'

	input:
	tuple val(sample_id), path(r1), path(r2)
	path reference_dir


	output:
	tuple val(sample_id), path("${sample_id}.sorted.bam"), path("${sample_id}.sorted.bam.bai")

	script:
	"""
	bwa mem $reference_dir/reference.fas $r1 $r2 | \
        samtools sort -o ${sample_id}.sorted.bam

	samtools index ${sample_id}.sorted.bam
	"""
}

process BAM_QC {

	conda '/home/gilbert/miniconda3/envs/ngs-align'
	
	publishDir "${params.outdir}/mapping/qc", mode: 'copy'

	input:
	tuple val(sample_id), path(bam), path(bai)

	output:
	path "*.bamcheck.txt"

	script:
	"""
	samtools quickcheck -v $bam > ${sample_id}.bamcheck.txt
	"""
}
process BAM_FLAGSTAT {

	conda '/home/gilbert/miniconda3/envs/ngs-align'
	
	publishDir "${params.outdir}/mapping/qc", mode: 'copy'

	input:
	tuple val(sample_id), path(bam), path(bai)

	output:
	path "*.flagstat.txt"

	script:
	"""
	samtools flagstat $bam > ${sample_id}.flagstat.txt
	"""	
}


process SPADES {

	conda '/home/gilbert/miniconda3/envs/ngs-align'

	publishDir "${params.outdir}/amr/assemblies/${sample_id}", mode: 'copy'

	input:
	tuple val(sample_id), path(r1), path(r2)

	output:
	tuple val(sample_id), path("contigs.fasta")

	script:
	"""
	spades.py \
        --pe1-1 $r1 \
        --pe1-2 $r2 \
        -o spades_out

	cp spades_out/contigs.fasta contigs.fasta
	"""
}

process ABRICATE {

	conda '/home/gilbert/miniconda3/envs/amr_plasmid_pipeline'

	publishDir "${params.outdir}/amr/resfinder", mode: 'copy'

	input:
	tuple val(sample_id), path(contigs)

	output:
	path "*.resfinder.tsv"

	script:
	"""
	abricate \
	--db resfinder \
        $contigs \
        > ${sample_id}.resfinder.tsv
	"""
}

process AMR_SUMMARY {

	publishDir "${params.outdir}/amr/summary", mode: 'copy'

	input:
	path resfinder_files

	output:
	path "AMR_summary.tsv"

	script:
	"""
	echo -e "Sample_ID\\tGene\\tCoverage\\tIdentity\\tDatabase\\tAccession\\tProduct\\tResistance" > AMR_summary.tsv

	for file in ${resfinder_files}; do
        sample_id=\$(basename "\$file" .resfinder.tsv)

        awk -F '\\t' -v sample="\$sample_id" '
        BEGIN { OFS="\\t" }
        !/^#/ {
            print sample, \$6, \$10, \$11, \$12, \$13, \$14, \$15
        }
        ' "\$file" >> AMR_summary.tsv
	done
	"""
}


process FREEBAYES {

	conda '/home/gilbert/miniconda3/envs/variant-calling'

	publishDir "${params.outdir}/variants/raw", mode: 'copy'

	input:
	tuple val(sample_id), path(bam), path(bai)
	path reference_dir

	output:
	path "*.vcf"

	script:
	"""
	freebayes \
        --ploidy 1 \
        -f $reference_dir/reference.fas \
        $bam \
        > ${sample_id}.vcf
	"""
}

process VCF_FILTER {

	conda '/home/gilbert/miniconda3/envs/variant-calling'
	
	publishDir "${params.outdir}/variants/filtered", mode: 'copy'

	input:
	path vcf
	
	output:
	path "*.filtered.vcf"

	script:
	"""
	bcftools view -i 'QUAL>=30 && INFO/DP>=10' $vcf \
        -o ${vcf.baseName}.filtered.vcf
	"""
}

process BCFTOOLS_NORM {

        conda '/home/gilbert/miniconda3/envs/variant-calling'
	
	publishDir "${params.outdir}/variants/normalized", mode: 'copy'

        input:
        path vcf
        path reference_dir

        output:
        path "*.normalized.vcf"

        script:
        """
        bcftools norm \
        -f $reference_dir/reference.fas \
        $vcf \
        -o ${vcf.baseName}.normalized.vcf
        """
}
process VCF_STATS {

        conda '/home/gilbert/miniconda3/envs/variant-calling'
	
	publishDir "${params.outdir}/variants/stats", mode: 'copy'

        input:
        path vcf

        output:
        path "*.stats.txt"

        script:
        """
        {
            echo "===== VCF SUMMARY ====="
            echo "Sample: ${vcf.baseName}"
            echo ""

            echo "Total variants:"
            grep -vc "^#" $vcf

            echo ""
            echo "SNPs:"
            grep -c "TYPE=snp" $vcf

            echo ""
            echo "Complex variants:"
            grep -c "TYPE=complex" $vcf
        } > ${vcf.baseName}.stats.txt
        """
}

process VCF_TABLE {

        conda '/home/gilbert/miniconda3/envs/variant-calling'
	
	publishDir "${params.outdir}/variants/tables", mode: 'copy'

        input:
        path vcf

        output:
        path "*.variants.tsv"

        script:
        """
        echo -e "CHROM\\tPOS\\tREF\\tALT\\tQUAL\\tDP\\tGT" > ${vcf.baseName}.variants.tsv

        bcftools query \
        -f '%CHROM\\t%POS\\t%REF\\t%ALT\\t%QUAL\\t%INFO/DP\\t[%GT]\\n' \
        $vcf >> ${vcf.baseName}.variants.tsv
        """
}
workflow {
	reads = channel.fromFilePairs('../fastqs/*_R{1,2}.fastq.gz',
        checkIfExists: true)

	paired_reads = reads.map { sample_id, files ->
        tuple(sample_id, files[0], files[1])
}

	reference = file('../reference.fas')
	
	FASTQC(paired_reads)

	TRIMMOMATIC(paired_reads)

	FASTQC_TRIMMED(TRIMMOMATIC.out)

	BWA_INDEX(reference)
	
	BWA_MEM(
	TRIMMOMATIC.out,
	BWA_INDEX.out)

	BAM_QC(BWA_MEM.out)
	
	BAM_FLAGSTAT(BWA_MEM.out)
	
	SPADES(TRIMMOMATIC.out)

	ABRICATE(SPADES.out)
	
	AMR_SUMMARY(ABRICATE.out.collect())
	
	FREEBAYES(
	BWA_MEM.out,
	BWA_INDEX.out)
	
	VCF_FILTER(FREEBAYES.out)

	BCFTOOLS_NORM(
	VCF_FILTER.out,
	BWA_INDEX.out)

	VCF_STATS(BCFTOOLS_NORM.out)


	VCF_TABLE(BCFTOOLS_NORM.out)
}
