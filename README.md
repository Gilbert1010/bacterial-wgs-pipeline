# Bacterial Whole-Genome Sequencing Pipeline

A reproducible bacterial whole-genome sequencing (WGS) analysis pipeline built with **Nextflow DSL2**. The workflow performs quality control, read trimming, reference-based mapping, BAM quality assessment, haploid variant calling, genome assembly, and antimicrobial resistance (AMR) gene detection.

## Overview

This pipeline is designed for bacterial paired-end WGS data and integrates two complementary analysis branches:

1. **Reference-based analysis** for read mapping and variant detection.
2. **De novo assembly-based analysis** for antimicrobial resistance gene detection.

The pipeline uses Nextflow to organize the analysis into reproducible, traceable and modular processes.

## Workflow

```text
                         ┌── FastQC
                         │
FASTQ ──► Trimmomatic ──┤
                         │
                         └── FastQC (trimmed reads)
                              │
                              ├── BWA-MEM ──► Sorted BAM
                              │                  │
                              │                  ├── BAM QC
                              │                  ├── Flagstat
                              │                  │
                              │                  └── FreeBayes
                              │                       │
                              │                       ├── VCF Filtering
                              │                       ├── BCFtools Normalization
                              │                       ├── Variant Statistics
                              │                       └── Variant Table
                              │
                              └── SPAdes
                                   │
                                   └── ABRicate
                                        │
                                        └── ResFinder
                                             │
                                             └── AMR Summary
```

## Pipeline Components

### 1. Raw Read Quality Control

**FastQC** is used to assess the quality of the original paired-end FASTQ reads.

Outputs include:

* HTML quality reports
* ZIP archives containing detailed FastQC results

### 2. Read Trimming

**Trimmomatic** is used to remove low-quality bases and filter short reads.

Current parameters:

```text
SLIDINGWINDOW:4:20
LEADING:3
TRAILING:3
MINLEN:36
```

Both paired and unpaired reads are generated during trimming. The paired reads are passed to downstream analysis.

### 3. Post-Trimming Quality Control

FastQC is run again on the trimmed paired reads to evaluate the quality improvement after preprocessing.

### 4. Reference Genome Indexing

The reference genome is indexed using **BWA** before read mapping.

The reference genome is supplied as:

```text
reference.fas
```

BWA index files are generated automatically during the pipeline run.

### 5. Read Mapping

Trimmed paired-end reads are mapped to the reference genome using:

```text
bwa mem
```

The resulting alignments are sorted using:

```text
samtools sort
```

and indexed using:

```text
samtools index
```

The final output is a coordinate-sorted BAM file for each sample.

### 6. BAM Quality Assessment

Two basic alignment quality checks are performed.

#### Samtools Quickcheck

```text
samtools quickcheck
```

This checks whether BAM files are structurally intact.

#### Samtools Flagstat

```text
samtools flagstat
```

This provides alignment statistics including:

* Total reads
* Mapped reads
* Properly paired reads
* Singleton reads
* Duplicate reads

### 7. Variant Calling

Variants are detected from the sorted BAM files using **FreeBayes**.

Because the pipeline is designed for bacterial genomes, FreeBayes is configured for haploid calling:

```text
--ploidy 1
```

The reference genome is used during variant calling.

### 8. Variant Filtering

Raw variants are filtered using **BCFtools**.

The current filtering criteria are:

```text
QUAL >= 30
DP >= 10
```

This removes variants with low quality or insufficient read depth.

### 9. Variant Normalization

Filtered variants are normalized against the reference genome using:

```text
bcftools norm
```

Normalization helps represent variants consistently, particularly for complex and indel-containing variants.

### 10. Variant Statistics

Basic statistics are generated for the normalized VCF files.

The current statistics include:

* Total number of variants
* Number of SNPs
* Number of complex variants

### 11. Variant Table

A simplified tabular representation of variants is generated containing:

```text
CHROM
POS
REF
ALT
QUAL
DP
GT
```

This makes downstream inspection and analysis easier.

### 12. De Novo Genome Assembly

Trimmed paired-end reads are assembled independently using **SPAdes**.

The resulting assembly contains:

```text
contigs.fasta
```

The assembly branch provides a reference-independent representation of the bacterial genome and is used for downstream AMR gene detection.

### 13. AMR Gene Detection

**ABRicate** is used with the **ResFinder** database to screen assembled contigs for antimicrobial resistance genes.

The output contains information such as:

* Gene
* Coverage
* Sequence identity
* Database
* Accession
* Product
* Resistance association

### 14. AMR Summary

Results from all samples are combined into a single:

```text
AMR_summary.tsv
```

file for easier comparison between samples.

## Software and Tools

 Tool           Purpose                            

 Nextflow DSL2  Workflow management                 
 FastQC         Read quality control                
 Trimmomatic    Read trimming                       
 BWA-MEM        Read alignment                      
 SAMtools       BAM processing and QC               
 FreeBayes      Variant calling                     
 BCFtools       Variant filtering and normalization 
 SPAdes         De novo genome assembly             
 ABRicate       AMR gene screening                  
 ResFinder      AMR gene database                   
 Conda          Software environment management     
 Git/GitHub     Version control              

## Input Data

The pipeline expects paired-end FASTQ files.

The current workflow searches for reads using:

```text
../fastqs/*_R{1,2}.fastq.gz
```

Expected structure:

```text
ghruexercise/
├── fastqs/
│   ├── Sample_001_R1.fastq.gz
│   ├── Sample_001_R2.fastq.gz
│   ├── Sample_002_R1.fastq.gz
│   └── Sample_002_R2.fastq.gz
│
├── reference.fas
│
└── bacterial-wgs-pipeline/
    ├── mainn.nf
    ├── nextflow.config
    ├── README.md
    └── .gitignore
```

The reference genome is currently specified as:

```text
../reference.fas
```

## Running the Pipeline

Navigate to the pipeline directory:

```bash
cd ~/ghruexercise/bacterial-wgs-pipeline
```

Run the pipeline with Conda:

```bash
nextflow run mainn.nf -with-conda
```

To resume an interrupted or partially completed run:

```bash
nextflow run mainn.nf -with-conda -resume
```

The `-resume` option allows Nextflow to reuse previously completed processes instead of repeating them unnecessarily.

## Configuration

The pipeline uses:

```text
nextflow.config
```

The current configuration includes:

* Local execution
* 4 CPUs
* Conda environment support
* Nextflow timeline
* Nextflow execution report
* Nextflow trace file

The default output directory is:

```text
results/
```

The output directory can be changed using the `outdir` parameter.

For example:

```bash
nextflow run mainn.nf -with-conda --outdir my_results
```

## Output Structure

The pipeline organizes results into separate analysis directories:

```text
results/
├── qc/
│   ├── raw/
│   └── trimmed/
│
├── trimmed/
│
├── reference/
│
├── mapping/
│   └── qc/
│
├── variants/
│   ├── raw/
│   ├── filtered/
│   ├── normalized/
│   ├── stats/
│   └── tables/
│
├── amr/
│   ├── assemblies/
│   ├── resfinder/
│   └── summary/
│
├── pipeline_timeline.html
├── pipeline_report.html
└── pipeline_trace.txt
```

### Quality Control

Raw and trimmed FastQC reports are stored under:

```text
results/qc/
```

### Trimmed Reads

Paired trimmed reads are stored under:

```text
results/trimmed/
```

### Mapping

Sorted BAM files and BAM indexes are stored under:

```text
results/mapping/
```

### Mapping QC

Alignment quality reports are stored under:

```text
results/mapping/qc/
```

### Variants

Raw VCF files:

```text
results/variants/raw/
```

Filtered VCF files:

```text
results/variants/filtered/
```

Normalized VCF files:

```text
results/variants/normalized/
```

Variant statistics:

```text
results/variants/stats/
```

Variant tables:

```text
results/variants/tables/
```

### AMR

Genome assemblies:

```text
results/amr/assemblies/
```

ResFinder results:

```text
results/amr/resfinder/
```

Combined AMR summary:

```text
results/amr/summary/AMR_summary.tsv
```

## Reproducibility

The project is version-controlled using Git and hosted on GitHub.

Important project files include:

```text
mainn.nf
nextflow.config
README.md
.gitignore
```

Nextflow also generates execution metadata including:

```text
pipeline_timeline.html
pipeline_report.html
pipeline_trace.txt
```

These files provide information about process execution, resource usage, timing, and workflow performance.

Generated analysis data and large sequencing files are excluded from version control through `.gitignore`.

## Current Analysis Capabilities

The pipeline currently supports:

* Raw sequencing read quality assessment
* Adapter and quality trimming
* Post-trimming quality assessment
* Reference genome indexing
* Paired-end read mapping
* Sorted BAM generation
* BAM integrity checking
* Alignment statistics
* Haploid bacterial variant calling
* Variant quality and depth filtering
* Variant normalization
* Basic variant statistics
* Tabular variant extraction
* De novo genome assembly
* AMR gene detection using ResFinder
* Consolidated AMR reporting
* Nextflow execution reporting and tracing

## Interpretation Notes

### Mapping and Coverage

Mapping statistics should be evaluated together with coverage and sequencing depth.

A high mapping percentage does not necessarily mean that the entire reference genome is adequately covered.

### Variant Calling

Variant calls should be interpreted in the context of:

* Read depth
* Variant quality
* Mapping quality
* Base quality
* Genomic position
* Potential repetitive regions
* Reference genome quality

The current filtering thresholds are intended as practical starting points and may require adjustment depending on the organism, sequencing platform, and research objective.

### AMR Gene Detection

Detection of an antimicrobial resistance gene indicates that a sequence matching the database entry was identified in the assembly.

**Gene detection alone does not prove phenotypic antimicrobial resistance.**

Phenotypic susceptibility testing and appropriate clinical or experimental validation are required when resistance results are used for clinical or diagnostic purposes.

### Reference-Based and Assembly-Based Results

The mapping and variant-calling branch and the assembly/AMR branch answer different biological questions.

Reference-based analysis focuses on:

```text
How does the sample differ from the selected reference genome?
```

The assembly and AMR branch focuses on:

```text
What genomic sequences and resistance-associated genes are present in the sample?
```

Together, these approaches provide complementary information about bacterial genomes.

## Project Purpose

This project was developed as a practical bacterial WGS bioinformatics workflow for learning, research, and reproducible genomic analysis.

The pipeline demonstrates how individual bioinformatics tools can be integrated into a single automated workflow using Nextflow DSL2.

Future development may include:

* Assembly quality assessment with QUAST
* Additional genome annotation
* More comprehensive variant statistics
* Phylogenetic analysis
* Enhanced AMR and virulence profiling
* Improved portability of software environments
* Containerized execution
* Automated biological interpretation and reporting

## Author

**Simeon Gilbert**

BSc Medical Laboratory Science
University of Ibadan

Areas of interest:

* Bioinformatics
* Genomics
* Molecular Biology
* Antimicrobial Resistance
* Bacterial Whole-Genome Sequencing
* Biotechnology

## Disclaimer

This pipeline is intended for research, educational and bioinformatics development purposes.

Results should be independently validated before being used for clinical, diagnostic, epidemiological or other high-stakes decision-making.
