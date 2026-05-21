process FASTQC {
    tag "FASTQC ${sample_label}"
    label 'process_low'

    input:
    tuple val(sample_label), path(bam)

    output:
    tuple val(sample_label), path("*_fastqc.zip"), path("*_fastqc.html")

    script:
    """
    fastqc ${bam} --outdir .
    """
}
