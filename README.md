# lorgen-annotation-filtering-pipeline

**Nextflow DSL2 pipeline for VCF annotation and rare-variant filtering.**

Takes VCF files from three known sources (NOVOGENE, NEXT, CEGAT), annotates them with gnomAD allele frequencies, and produces filtered VCFs retaining only rare variants — optionally restricted to a gene list.

---

## Pipeline overview

```
vcf_dir/{NOVOGENE,NEXT,CEGAT}/
  └─ MERGE_SNP_INDEL    NOVOGENE only: merge per-sample SNP + Indel VCFs
  └─ NORMALIZE_VCF      normalise multiallelic sites (bcftools norm)
  └─ ANNOTATE_VCF       annotate with gnomAD allele frequency (gnomAD_AF)
  └─ FILTER_AF          retain PASS variants with gnomAD_AF < 0.05
  └─ FILTER_BY_GENES    filter by gene list (genes.txt); skipped if file is empty
```

All three sources use `chr`-prefixed chromosome names, same as the gnomAD reference (`gnomad.withchr.bgz.vcf.gz`) — no chromosome renaming is needed.

---

## Input directory layout

VCFs are organised by source folder. NOVOGENE delivers SNPs and Indels as separate per-sample files (same prefix, `.snp.`/`.indel.` in the name); NEXT and CEGAT deliver one VCF per sample. An optional `genes.txt` lives at the root and applies to all sources.

```
vcf_input/
├── VCF_NOVOGENE/
│   ├── D10017772.GATK.snp.vcf.gz
│   ├── D10017772.GATK.indel.vcf.gz
│   ├── D10017773.GATK.snp.vcf.gz
│   └── D10017773.GATK.indel.vcf.gz
├── VCF_NEXT/
│   └── sampleA.vcf.gz
├── VCF_CEGAT/
│   └── sampleB.vcf.gz
└── genes.txt          # optional — one gene name per line
                       # empty or absent → no gene filtering applied
```

`genes.txt` example:
```
BRCA1
BRCA2
TP53
```

Any source folder may be empty (its samples are simply skipped). If **all three** are empty, the pipeline stops with an error.

---

## Parameters

| Parameter | Description | Default |
|---|---|---|
| `--vcf_dir` | Directory containing `VCF_NOVOGENE/`, `VCF_NEXT/`, `VCF_CEGAT/` subfolders and optional `genes.txt` | `null` (required) |
| `--exome_vcf` | gnomAD VCF (bgzipped + tabix-indexed) | `/mnt/data/exome/gnomad.withchr.bgz.vcf.gz` |
| `--exome_index` | gnomAD `.tbi` tabix index | `/mnt/data/exome/gnomad.withchr.bgz.vcf.gz.tbi` |
| `--gene_list` | Explicit path to gene list (overrides auto-detection in `--vcf_dir`) | `null` |
| `--results_dir` | Output directory | `./results` |

---

## Usage

### Server directory layout

```
lorgen_annotation_pipeline/
├── data/
│   ├── vcf_input/      ← NOVOGENE/, NEXT/, CEGAT/ + genes.txt
│   └── references/     ← gnomAD VCF + index
├── results/            ← pipeline outputs (--results_dir)
├── logs/               ← Nextflow execution logs (-log)
└── work/               ← Nextflow work directory, temporary (-work-dir)
```

### Run

```bash
nextflow run main_annotation.nf \
  -C conf/annotation.config \
  -profile docker \
  -log         lorgen_annotation_pipeline/logs/nextflow.log \
  -work-dir    lorgen_annotation_pipeline/work \
  --vcf_dir      lorgen_annotation_pipeline/data/vcf_input \
  --results_dir  lorgen_annotation_pipeline/results
```

`--exome_vcf` and `--exome_index` already point to the gnomAD files on the server (`/mnt/data/exome/gnomad.withchr.bgz.vcf.gz`) by default — no need to pass them unless you want to use a different reference.

For long-running jobs, use `screen` or `tmux`:

```bash
screen -S annotation
nextflow run main_annotation.nf -C conf/annotation.config -profile docker ...
```

---

## Outputs

All outputs are written to `--results_dir` (default: `./results`):

```
results/
└── vcf/
    ├── *_merged.vcf.gz        NOVOGENE only — merged SNP+Indel VCF
    ├── *_norm.vcf.gz          normalised VCF
    ├── *_annotated.vcf.gz     gnomAD-annotated VCF
    ├── *_filtered.vcf.gz      AF-filtered VCF (PASS + gnomAD_AF < 0.05)
    └── *_final.vcf.gz         gene-filtered final VCF
```

---

## Requirements

| Tool | Minimum version |
|---|---|
| [Nextflow](https://www.nextflow.io/) | 23.04 |
| [Docker](https://www.docker.com/) **or** [Singularity](https://sylabs.io/) | any recent |
| Java | 17 |

---

## Repository structure

```
.
├── main_annotation.nf               entry point
├── conf/
│   └── annotation.config            standalone config for this pipeline
├── workflows/
│   └── annotation_filtering.nf
└── modules/local/
    ├── merge_snp_indel.nf           NOVOGENE — merge SNP + Indel VCFs
    ├── normalize_vcf.nf             normalise multiallelic sites
    ├── annotate_vcf.nf              gnomAD annotation
    ├── filter_af.nf                 PASS + AF filtering
    └── filter_by_genes.nf           gene filtering
```

---

## Data availability

This repository contains pipeline code only. No sequencing data, reference genomes, or variant databases are included. Input files must be supplied by the user.

---

## Citation

If you use this pipeline, please cite:

**This pipeline:**
Chica Redecillas L. (2026). *lorgen-annotation-filtering-pipeline*. GitHub.

**Underlying tools:**
- Danecek P et al. (2021). Twelve years of SAMtools and BCFtools. *GigaScience*, 10(2). [bcftools]
- Karczewski KJ et al. (2020). The mutational constraint spectrum quantified from variation in 141,456 humans. *Nature*, 581:434–443. [gnomAD]

---

## Contributors

**Lucía Chica Redecillas**
chica.redecillas.l@gmail.com — [LUCIACHICAR](https://github.com/LUCIACHICAR)
