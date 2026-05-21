process CALL_VARIANTS {
    tag "CALL_VARIANTS ${sample_id}"
    label 'process_medium'

    input:
    tuple val(sample_id), path(bam), path(bai), path(genome)

    output:
    tuple val(sample_id), path("${sample_id}_raw.vcf")

    script:
    """
    bcftools mpileup -Ou -f ${genome} ${bam} |
    bcftools call -mv -Ou |
    bcftools filter -s LowQual -e 'QUAL<30 || DP<10' -Ov -o ${sample_id}_raw.vcf
    """
}
