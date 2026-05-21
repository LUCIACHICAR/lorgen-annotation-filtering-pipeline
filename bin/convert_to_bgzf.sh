#!/bin/bash
# Converts a gnomAD VCF from numeric chromosome names (1, 2, ...) to
# "chr"-prefixed names (chr1, chr2, ...) and recompresses in BGZF format
# with a tabix index, as required by bcftools annotate.
#
# Usage:
#   convert_to_bgzf.sh <input_vcf.bgz> <output_dir>
#
# Example:
#   convert_to_bgzf.sh gnomad.exomes.r2.1.1.sites.vcf.bgz /data/exome
#
# Requirements: bcftools, bgzip, tabix (all from htslib)

set -euo pipefail

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <input_vcf.bgz> <output_dir>"
    exit 1
fi

VCF_ORIG="$1"
OUT_DIR="$2"

CHR_MAP="${OUT_DIR}/chr_map_to_chr.txt"
VCF_RENAMED="${OUT_DIR}/gnomad.withchr.vcf.gz"
TEMP="${OUT_DIR}/gnomad.withchr.vcf"
OUTPUT="${OUT_DIR}/gnomad.withchr.bgz.vcf.gz"

# Check for required tools
command -v bcftools >/dev/null 2>&1 || { echo >&2 "ERROR: bcftools not found. Install bcftools."; exit 1; }
command -v bgzip    >/dev/null 2>&1 || { echo >&2 "ERROR: bgzip not found. Install htslib.";    exit 1; }
command -v tabix    >/dev/null 2>&1 || { echo >&2 "ERROR: tabix not found. Install htslib.";    exit 1; }

mkdir -p "$OUT_DIR"

# Step 0: Create chromosome name mapping file
echo "Creating chromosome mapping file..."
cat > "$CHR_MAP" <<EOF
1	chr1
2	chr2
3	chr3
4	chr4
5	chr5
6	chr6
7	chr7
8	chr8
9	chr9
10	chr10
11	chr11
12	chr12
13	chr13
14	chr14
15	chr15
16	chr16
17	chr17
18	chr18
19	chr19
20	chr20
21	chr21
22	chr22
X	chrX
Y	chrY
MT	chrM
EOF

# Step 1: Rename chromosome names
echo "Renaming chromosomes in ${VCF_ORIG}..."
bcftools annotate --rename-chrs "$CHR_MAP" "$VCF_ORIG" -Oz -o "$VCF_RENAMED"

# Step 2: Decompress for BGZF recompression
echo "Decompressing ${VCF_RENAMED}..."
gunzip -c "$VCF_RENAMED" > "$TEMP"

# Step 3: Compress with BGZF
echo "Compressing to BGZF as ${OUTPUT}..."
bgzip -c "$TEMP" > "$OUTPUT"

# Step 4: Index with tabix
echo "Indexing ${OUTPUT}..."
tabix -p vcf "$OUTPUT"

# Step 5: Clean up intermediate files
echo "Cleaning up..."
rm -f "$TEMP"

echo "Done. BGZF-compressed and indexed file: ${OUTPUT}"
