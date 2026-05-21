process MARK_DUPLICATES {
    label 'process_medium'

    input:
    tuple val(sample_id), path(sorted_bam)

    output:
    tuple val(sample_id), path("${sample_id}_dedup.bam"), path("${sample_id}_dupmetrics.txt")

    script:
    """
    samtools sort -n -o temp_query_sorted.bam ${sorted_bam}
    samtools fixmate -m temp_query_sorted.bam temp_fixmate.bam
    samtools sort -o temp_fixmate_sorted.bam temp_fixmate.bam
    samtools markdup -r -s temp_fixmate_sorted.bam ${sample_id}_dedup.bam 2> ${sample_id}_dupmetrics.txt
    """
}
