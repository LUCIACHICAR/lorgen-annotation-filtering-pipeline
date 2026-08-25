# lorgen-annotation-filtering-pipeline

**Nextflow DSL2 pipeline for VCF annotation and rare-variant filtering.**

Takes VCF files from three known sources (NOVOGENE, NEXT, CEGAT), annotates them with gnomAD allele frequencies, and produces filtered VCFs retaining only rare variants — optionally restricted to a gene list.

---

## Pipeline overview

```
vcf_dir/{NOVOGENE,NEXT,CEGAT}/
  └─ MERGE_SNP_INDEL    NOVOGENE only: merge per-sample SNP + Indel VCFs
  └─ NORMALIZE_VCF      split multiallelic sites and left-align indels (bcftools norm -f -c e)
  └─ ANNOTATE_VCF       annotate with gnomAD allele frequency (gnomAD_AF)
  └─ FILTER_AF          retain PASS variants with gnomAD_AF < 0.05, or no gnomAD_AF at all
  └─ ANNOTATE_GENES     assign gene(s) overlapping each variant's position (GENCODE BED)
  └─ FILTER_BY_GENES    filter by gene list (genes.txt); skipped if file is empty
```

All three sources use `chr`-prefixed chromosome names, same as the gnomAD reference (`gnomad.withchr.bgz.vcf.gz`) — no chromosome renaming is needed.

**NOVOGENE SNP+Indel matching:** two files merge only if their names are identical except for the `snp`/`indel` token. A sample with only one of the two files proceeds with a warning; anything else (an unrecognised filename, or more/duplicate files for the same sample) stops the pipeline with an error rather than guessing.

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
| `--reference_fasta` | Reference genome FASTA matching the gnomAD build (GRCh37, `chr`-prefixed), indexed with `samtools faidx` — used to left-align indels | `/mnt/data/hg19_ref_genome/genome.fa` |
| `--reference_fasta_index` | `.fai` index of the reference FASTA | `/mnt/data/hg19_ref_genome/genome.fa.fai` |
| `--genes_bed` | Gene regions (BED, bgzipped + tabix-indexed; `chrom, start, end, gene`), derived from a GENCODE GTF — used to assign genes by position overlap | `/mnt/data/hg19_ref_genome/genes.bed.gz` |
| `--genes_bed_index` | `.tbi` index of `--genes_bed` | `/mnt/data/hg19_ref_genome/genes.bed.gz.tbi` |
| `--gene_list` | Explicit path to gene list (overrides auto-detection in `--vcf_dir`) | `null` |
| `--results_dir` | Output directory | `./results` |

---

## Usage

### Server directory layout

```
lorgen_annotation_pipeline/     ← this repo, cloned on the server
├── data/
│   └── vcf_input/      ← NOVOGENE/, NEXT/, CEGAT/ + genes.txt
├── results/            ← pipeline outputs (--results_dir)
├── logs/               ← Nextflow execution logs (-log)
└── work/               ← Nextflow work directory, temporary (-work-dir)

/mnt/data/                      ← shared reference files, outside this repo
├── exome/               ← gnomAD VCF + index
└── hg19_ref_genome/     ← reference FASTA + genes BED (see Parameters)
```

### Run

`run.sh` wraps the full command below — the only two things to edit between runs are the two paths at the top of that file (`VCF_DIR`, `RESULTS_DIR`); the Nextflow invocation itself never needs to change:

```bash
screen -dRR annotation   # keeps running if the SSH session drops; Ctrl+A D to detach
./run.sh
```

Equivalent, spelled out in full:

```bash
nextflow -log lorgen_annotation_pipeline/logs/nextflow.log -C conf/annotation.config run main_annotation.nf \
  -profile docker \
  -work-dir    lorgen_annotation_pipeline/work \
  --vcf_dir      lorgen_annotation_pipeline/data/vcf_input \
  --results_dir  lorgen_annotation_pipeline/results
```

`--exome_vcf`, `--exome_index`, `--reference_fasta`, `--reference_fasta_index`, `--genes_bed` and `--genes_bed_index` already point to the reference files on the server by default — no need to pass them unless you want to use different ones.

---

## Outputs

All outputs are written to `--results_dir` (default: `./results`):

```
results/
└── vcf/
    ├── *_merged.vcf.gz        NOVOGENE only — merged SNP+Indel VCF
    ├── *_norm.vcf.gz          normalised + left-aligned VCF
    ├── *_annotated.vcf.gz     gnomAD-annotated VCF
    ├── *_filtered.vcf.gz      AF-filtered VCF (PASS + rare or absent from gnomAD)
    ├── *_genes.vcf.gz         gene-annotated VCF (INFO/GENE)
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
├── run.sh                           wrapper script — the only thing analysts run
├── conf/
│   └── annotation.config            standalone config for this pipeline
├── workflows/
│   └── annotation_filtering.nf
├── modules/local/
│   ├── merge_snp_indel.nf           NOVOGENE — merge SNP + Indel VCFs
│   ├── normalize_vcf.nf             split multiallelics, left-align indels
│   ├── annotate_vcf.nf              gnomAD annotation
│   ├── filter_af.nf                 PASS + AF filtering
│   ├── annotate_genes.nf            gene assignment by position overlap
│   └── filter_by_genes.nf           gene filtering
└── tests/                           synthetic and real-variant fixtures (see each README inside)
```

---

## Data availability

This repository contains pipeline code only. No sequencing data, reference genomes, or variant databases are included. Input files must be supplied by the user.

---

## Citation

If you use this pipeline, please cite:

**This pipeline:**
Chica-Redecillas L. (2026). *lorgen-annotation-filtering-pipeline*. GitHub.

**Underlying tools:**
- Danecek P et al. (2021). Twelve years of SAMtools and BCFtools. *GigaScience*, 10(2). [bcftools]
- Karczewski KJ et al. (2020). The mutational constraint spectrum quantified from variation in 141,456 humans. *Nature*, 581:434–443. [gnomAD]

---

## Contributors

**Lucía Chica-Redecillas**
chica.redecillas.l@gmail.com — [LUCIACHICAR](https://github.com/LUCIACHICAR)
