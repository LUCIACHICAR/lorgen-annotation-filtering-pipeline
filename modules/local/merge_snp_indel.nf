process MERGE_SNP_INDEL {
    tag "MERGE_SNP_INDEL ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcfs)

    output:
    tuple val(sample_id), path("${sample_id}_merged.vcf.gz")

    script:
    """
    for f in ${vcfs}; do tabix -p vcf -f \$f; done
    bcftools concat -a ${vcfs} -Ou | bcftools sort -Oz -o ${sample_id}_merged.vcf.gz
    """
}
