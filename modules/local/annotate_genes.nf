process ANNOTATE_GENES {
    tag "ANNOTATE_GENES ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcf), path(vcf_index)
    path genes_bed
    path genes_bed_index

    output:
    tuple val(sample_id), path("${sample_id}_genes.vcf.gz"), path("${sample_id}_genes.vcf.gz.tbi")

    script:
    """
    # Adds INFO/GENE with every gene whose region overlaps this variant's position
    # (positional overlap against a GENCODE gene BED — not a functional-effect
    # call; that is left to downstream interpretation).
    #
    # -l GENE:unique collects ALL overlapping genes for a position instead of
    # silently keeping only the first match bcftools finds when two gene regions
    # overlap (e.g. DDX11L1/WASH7P) — verified against a real overlapping pair
    # before relying on it; without -l, a variant could quietly lose one of its
    # genes and never turn up when filtering by that gene's name.
    cat > gene_header.txt << 'HEADER'
##INFO=<ID=GENE,Number=.,Type=String,Description="Gene(s) overlapping this variant, by position (GENCODE v19, GRCh37)">
HEADER

    bcftools annotate \
        -a ${genes_bed} \
        -c CHROM,FROM,TO,GENE \
        -h gene_header.txt \
        -l GENE:unique \
        ${vcf} \
        -Oz -o ${sample_id}_genes.vcf.gz

    tabix -p vcf ${sample_id}_genes.vcf.gz
    """
}
