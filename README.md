# Bacterial Whole-Genome Sequencing Pipeline

A reproducible bacterial whole-genome sequencing (WGS) analysis pipeline built with Nextflow DSL2.

## Overview

This pipeline processes paired-end bacterial WGS reads through quality control, read trimming, reference-based mapping, variant calling, genome assembly, and antimicrobial resistance (AMR) gene detection.

## Workflow

FASTQ
↓
FastQC
↓
Trimmomatic
↓
FastQC (trimmed reads)
↓
BWA Mapping
↓
BAM QC
├── FreeBayes
│   ├── VCF Filtering
│   ├── BCFtools Normalization
│   ├── Variant Statistics
│   └── Variant Table
│
└── SPAdes
    ↓
  ABRicate
    ↓
  ResFinder
    ↓
  AMR Summary

## Tools

- Nextflow
- FastQC
- Trimmomatic
- BWA
- Samtools
- FreeBayes
- BCFtools
- SPAdes
- ABRicate
- ResFinder

## Pipeline Features

### Quality Control
Raw and trimmed reads are assessed using FastQC.

### Read Trimming
Paired-end reads are quality trimmed using Trimmomatic.

### Reference Mapping
Reads are mapped to a reference genome using BWA and processed into sorted BAM files.

### Variant Calling
Variants are identified using FreeBayes with haploid bacterial calling:

```text
--ploidy 1
