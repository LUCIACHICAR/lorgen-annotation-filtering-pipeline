process ANNOTATE_VCF {
    tag "ANNOTATE_VCF ${sample_id}"
    label 'process_medium'

    input:
    tuple val(sample_id), path(vcf), path(vcf_index)
    path exome_vcf
    path exome_index

    output:
    tuple val(sample_id), path("${sample_id}_annotated.vcf.gz"), path("${sample_id}_annotated.vcf.gz.tbi")

    script:
    """
    # Annotate with gnomAD allele frequency
    bcftools annotate --threads ${task.cpus} \
        -a ${exome_vcf} \
        -c 'INFO/gnomAD_AF:=AF' \
        ${vcf} \
        -Oz -o ${sample_id}_annotated.vcf.gz
    tabix -p vcf ${sample_id}_annotated.vcf.gz
    """
}
