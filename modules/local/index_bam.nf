process INDEX_BAM {
    label 'process_low'

    input:
    tuple val(sample_id), path(bam)

    output:
    tuple val(sample_id), path(bam), path("${bam}.bai")

    script:
    """
    samtools index ${bam}
    """
}
