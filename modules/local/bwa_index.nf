process BWA_INDEX {
    label 'process_medium'

    input:
    path genome

    output:
    path "genome.fa.*"

    script:
    """
    bwa index $genome
    """
}
