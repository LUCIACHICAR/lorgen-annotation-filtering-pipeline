process FILTER_AF {
    tag "FILTER_AF ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcf), path(vcf_index)

    output:
    tuple val(sample_id), path("${sample_id}_filtered.vcf.gz"), path("${sample_id}_filtered.vcf.gz.*")

    script:
    """
    # Retain PASS variants with gnomAD AF < 0.05 or no gnomAD AF annotation (e.g. novel variants).
    bcftools view --threads ${task.cpus} -f PASS -i 'INFO/gnomAD_AF<0.05 || gnomAD_AF="."' ${vcf} -Oz -o ${sample_id}_filtered.vcf.gz
    bcftools index -f ${sample_id}_filtered.vcf.gz
    """
}
