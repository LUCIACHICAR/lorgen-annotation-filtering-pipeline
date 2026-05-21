# lorgen-variant-calling-pipeline

**Nextflow DSL2 pipeline for targeted DNA sequencing panels.**  
Performs paired-end read alignment, duplicate marking, variant calling, and gnomAD allele-frequency filtering to produce a clean set of rare somatic or germline variants within user-defined target regions.

---

## Pipeline overview

```
FASTQ (paired-end, multi-lane)
  └─ MERGE_LANES         cat lane files per sample
  └─ FASTQC (aligned)    QC on aligned BAMs
  └─ ALIGN_READS         bwa mem → samtools view (BAM)
  └─ SORT_BAM            samtools sort
  └─ MARK_DUPLICATES     samtools fixmate / markdup
  └─ INDEX_BAM           samtools index
  └─ FASTQC (dedup)      QC on deduplicated BAMs
  └─ CALL_VARIANTS       bcftools mpileup | call | filter
  └─ FILTER_VCF_AF       bgzip → tabix → bcftools annotate (gnomAD) → filter AF < 0.05
  └─ MULTIQC             aggregate FastQC reports
```

Variants are retained only if they meet **all** of the following criteria:

- Quality score (QUAL) > 30
- Read depth (DP) ≥ 10
- Within target regions supplied in the BED file
- gnomAD exome allele frequency (AF) < 0.05

---

## Requirements

| Tool | Minimum version |
|---|---|
| [Nextflow](https://www.nextflow.io/) | 23.04 |
| [Docker](https://www.docker.com/) **or** [Singularity](https://sylabs.io/) | any recent |
| Java | 17 |

---

## Input preparation

### 1. FASTQ files

Paired-end FASTQ files must follow Illumina's standard naming convention. The pipeline automatically detects and merges reads across two lanes (L001 and L002) per sample:

```
reads/
├── sample1_S1_L001_R1_001.fastq.gz
├── sample1_S1_L001_R2_001.fastq.gz
├── sample1_S1_L002_R1_001.fastq.gz
└── sample1_S1_L002_R2_001.fastq.gz
```

### 2. Reference genome (hg19)

The pipeline was developed and validated against **hg19** (GRCh37). After downloading, index the FASTA with BWA:

```bash
bwa index genome.fa
```

### 3. gnomAD VCF

Download the gnomAD r2.1.1 exome VCF:

```bash
wget https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.vcf.bgz
wget https://storage.googleapis.com/gcp-public-data--gnomad/release/2.1.1/vcf/exomes/gnomad.exomes.r2.1.1.sites.vcf.bgz.tbi
```

The gnomAD VCF uses numeric chromosome names (1, 2, …) while hg19 uses "chr"-prefixed names (chr1, chr2, …). Convert with the helper script:

```bash
chmod +x bin/convert_to_bgzf.sh
bin/convert_to_bgzf.sh gnomad.exomes.r2.1.1.sites.vcf.bgz /path/to/output/dir
```

This produces `gnomad.withchr.bgz.vcf.gz` and its `.tbi` index.

### 4. Target regions BED file

Provide a BED file defining the sequenced panel regions. Pass it via `--exome_bed`. The default placeholder name is `targets.bed`.

---

## Parameters

| Parameter | Description | Default |
|---|---|---|
| `--reads_dir` | Directory containing paired FASTQ files | `null` (required) |
| `--genome_fasta` | Path to hg19 reference FASTA (with BWA index) | `null` (required) |
| `--exome_vcf` | Path to gnomAD VCF (bgzipped, chr-prefixed) | `null` (required) |
| `--exome_index` | Path to gnomAD VCF `.tbi` tabix index | `null` (required) |
| `--exome_bed` | Path to target regions BED file | `null` (required) |
| `--results_dir` | Output directory | `./results` |

---

## Usage

### Docker profile

```bash
nextflow run fpmartinez10/lorgen-variant-calling-pipeline \
  -profile docker \
  --reads_dir      /path/to/reads \
  --genome_fasta   /path/to/genome.fa \
  --exome_vcf      /path/to/gnomad.withchr.bgz.vcf.gz \
  --exome_index    /path/to/gnomad.withchr.bgz.vcf.gz.tbi \
  --exome_bed      /path/to/targets.bed
```

### Singularity profile

```bash
nextflow run fpmartinez10/lorgen-variant-calling-pipeline \
  -profile singularity \
  --reads_dir      /path/to/reads \
  --genome_fasta   /path/to/genome.fa \
  --exome_vcf      /path/to/gnomad.withchr.bgz.vcf.gz \
  --exome_index    /path/to/gnomad.withchr.bgz.vcf.gz.tbi \
  --exome_bed      /path/to/targets.bed
```

For long-running jobs on a remote server, use `screen` or `tmux` to prevent interruption on disconnection:

```bash
screen -S lorgen
nextflow run fpmartinez10/lorgen-variant-calling-pipeline -profile docker ...
```

---

## Outputs

All outputs are written to `--results_dir` (default: `./results`):

```
results/
├── bam/
│   ├── *_aligned.bam          aligned BAMs
│   ├── *_sorted.bam           coordinate-sorted BAMs
│   └── *_dedup.bam            deduplicated BAMs + duplicate metrics
├── vcf/
│   ├── *_raw.vcf              unfiltered variant calls
│   └── *_final_filtered.vcf.gz   AF-filtered variants (index included)
├── fastqc/                    per-sample FastQC reports (aligned + dedup)
├── multiqc/
│   └── multiqc_report.html    aggregated QC summary
├── pipeline_report.html       Nextflow execution report
├── pipeline_timeline.html     process timeline
├── pipeline_trace.txt         per-task resource usage
└── pipeline_dag.png           pipeline DAG
```

---

## Docker image note

The alignment step (`ALIGN_READS`, `BWA_INDEX`) uses the custom Docker image `fpmartinez10/bwa-samtools:1.1`, which bundles BWA and SAMtools. If you prefer not to use this image, you can substitute any image that provides both tools, for example:

- `quay.io/biocontainers/bwa:0.7.17--h5bf99c6_8` (BWA only — combine with a SAMtools image via a multi-step approach)
- Build your own from a `Dockerfile` with `bwa` and `samtools` installed

All other processes use publicly available [BioContainers](https://biocontainers.pro/) images.

---

## Data availability

This repository contains **pipeline code only**. No sequencing data, reference genomes, or variant databases are included. Input files must be supplied by the user.

---

## Citation

If you use this pipeline, please cite:

**This pipeline:**  
Perez Martinez F, Castañeda Sastre E. (2025). *lorgen-variant-calling-pipeline* (v1.0.0). GitHub. https://github.com/fpmartinez10/lorgen-variant-calling-pipeline

**Underlying tools:**  
- Li H, Durbin R. (2009). Fast and accurate short read alignment with Burrows-Wheeler Aligner. *Bioinformatics*, 25(14):1754–1760. [BWA]
- Danecek P et al. (2021). Twelve years of SAMtools and BCFtools. *GigaScience*, 10(2). [SAMtools / bcftools]
- Andrews S. (2010). FastQC: A Quality Control Tool for High Throughput Sequence Data. https://www.bioinformatics.babraham.ac.uk/projects/fastqc/ [FastQC]
- Ewels P et al. (2016). MultiQC: summarize analysis results for multiple tools and samples in a single report. *Bioinformatics*, 32(19):3047–3048. [MultiQC]
- Karczewski KJ et al. (2020). The mutational constraint spectrum quantified from variation in 141,456 humans. *Nature*, 581:434–443. [gnomAD]

---

## Contributors

**Erika Castañeda Sastre**  
📧 erikatatianacs@gmail.com  
🐙 [ErikaBioInfo](https://github.com/ErikaBioInfo)

**Felipe Perez Martinez**  
📧 fpmartinez10@gmail.com  
🐙 [fpmartinez10](https://github.com/fpmartinez10)

---

If you find this pipeline useful, consider starring the repository ⭐ and sharing it with colleagues working on targeted sequencing panels.
