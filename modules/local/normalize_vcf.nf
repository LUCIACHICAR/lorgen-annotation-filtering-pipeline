process NORMALIZE_VCF {
    tag "NORMALIZE_VCF ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcf)

    output:
    tuple val(sample_id), path("${sample_id}_norm.vcf.gz"), path("${sample_id}_norm.vcf.gz.tbi")

    script:
    """
    bcftools norm -m -any ${vcf} -Oz -o ${sample_id}_norm.vcf.gz
    tabix -p vcf ${sample_id}_norm.vcf.gz
    """
}
