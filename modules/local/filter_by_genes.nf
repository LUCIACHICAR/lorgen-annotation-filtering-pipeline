process FILTER_BY_GENES {
    tag "FILTER_BY_GENES ${sample_id}"
    label 'process_low'

    input:
    tuple val(sample_id), path(vcf), path(vcf_index)
    path gene_list

    output:
    tuple val(sample_id), path("${sample_id}_final.vcf.gz"), path("${sample_id}_final.vcf.gz.tbi")

    script:
    """
    # If gene list is empty, pass the VCF through unchanged
    if [ ! -s ${gene_list} ]; then
        cp ${vcf}     ${sample_id}_final.vcf.gz
        cp ${vcf_index} ${sample_id}_final.vcf.gz.tbi
        exit 0
    fi

    # Build bcftools include expression: INFO/GENE="BRCA1" || INFO/GENE="BRCA2" ...
    GENE_EXPR=\$(awk 'NF{printf "%sINFO/GENE=\\"%s\\"", (NR>1?" || ":""), \$1}' ${gene_list})

    bcftools view --threads ${task.cpus} \
        -i "\$GENE_EXPR" \
        ${vcf} \
        -Oz -o ${sample_id}_final.vcf.gz
    tabix -p vcf ${sample_id}_final.vcf.gz
    """
}
