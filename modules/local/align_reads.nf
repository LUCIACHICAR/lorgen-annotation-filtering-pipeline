process ALIGN_READS {
    tag "ALIGN_READS ${sample_id}"
    label 'process_high'

    input:
    tuple val(sample_id), path(r1), path(r2), path(genome), path(genome_index_files)

    output:
    tuple val(sample_id), path("${sample_id}_aligned.bam")

    script:
    """
    bwa mem -t ${task.cpus} $genome $r1 $r2 | samtools view -Sb - > ${sample_id}_aligned.bam
    """
}
