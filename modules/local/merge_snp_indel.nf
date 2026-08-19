process MERGE_SNP_INDEL {
    tag "MERGE_SNP_INDEL ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcfs)

    output:
    tuple val(sample_id), path("${sample_id}_merged.vcf.gz")

    script:
    """
    # Nextflow runs now pipefail. Without it, if 'bcftools concat' below fails partway
    # through, 'bcftools sort' can still succeed on the truncated stream it
    # received and exit 0 — Nextflow would then mark this task as completed
    # with a valid-looking but incomplete merged VCF, silently missing variants.
    set -euo pipefail

    for f in ${vcfs}; do tabix -p vcf -f \$f; done
    bcftools concat -a ${vcfs} -Ou | bcftools sort -Oz -o ${sample_id}_merged.vcf.gz
    """
}
