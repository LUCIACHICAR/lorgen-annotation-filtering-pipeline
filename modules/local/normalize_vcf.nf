process NORMALIZE_VCF {
    tag "NORMALIZE_VCF ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcf)
    path reference_fasta
    path reference_fasta_index

    output:
    tuple val(sample_id), path("${sample_id}_norm.vcf.gz"), path("${sample_id}_norm.vcf.gz.tbi")

    script:
    """
    # -f alinea los indels a la izquierda contra el genoma de referencia (si no,
    # solo se dividen multialélicos con -m -any, sin normalizar indels).
    # -c e para inmediatamente si el REF del VCF no coincide con la referencia:
    # eso solo puede pasar si el genoma de referencia no es el correcto, o hay
    # un problema real de datos — mejor parar aquí que seguir con algo mal.
    bcftools norm \
        -f ${reference_fasta} \
        -c e \
        -m -any \
        ${vcf} \
        -Oz \
        -o ${sample_id}_norm.vcf.gz

    tabix -p vcf ${sample_id}_norm.vcf.gz
    """
}
