#!/bin/bash
set -euo pipefail

# ── Lo único que se puede tocar entre ejecuciones ──────────────────────
VCF_DIR="$HOME/lorgen_annotation_pipeline/data/vcf_input"
RESULTS_DIR="$HOME/lorgen_annotation_pipeline/results"
# ────────────────────────────────────────────────────────────────────

# A partir de aquí, no tocar — no cambia entre ejecuciones.
cd "$HOME/lorgen_annotation_pipeline"
nextflow -log "$HOME/lorgen_annotation_pipeline/logs/nextflow.log" -C conf/annotation.config run main_annotation.nf \
  -profile docker \
  -work-dir "$HOME/lorgen_annotation_pipeline/work" \
  --vcf_dir "$VCF_DIR" \
  --results_dir "$RESULTS_DIR"
