process MERGE_LANES {
    label 'process_low'

    input:
    tuple val(sample_id), val(reads_dir)

    output:
    tuple val(sample_id), path("${sample_id}_R1.fq.gz"), path("${sample_id}_R2.fq.gz")

    script:
    """
    cat ${reads_dir}/${sample_id}_L001_R1_001.fastq.gz ${reads_dir}/${sample_id}_L002_R1_001.fastq.gz > ${sample_id}_R1.fq.gz
    cat ${reads_dir}/${sample_id}_L001_R2_001.fastq.gz ${reads_dir}/${sample_id}_L002_R2_001.fastq.gz > ${sample_id}_R2.fq.gz
    """
}
