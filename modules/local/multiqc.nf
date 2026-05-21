process MULTIQC {
    tag "MULTIQC"
    label 'process_low'

    input:
    path fastqc_outputs

    output:
    path "multiqc_report.html"

    script:
    """
    mkdir -p fastqc_inputs
    cp ${fastqc_outputs.join(' ')} fastqc_inputs/
    multiqc fastqc_inputs --force --outdir .
    """
}
