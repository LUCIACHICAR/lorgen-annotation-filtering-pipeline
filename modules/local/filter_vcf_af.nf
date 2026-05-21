process FILTER_VCF_AF {
    tag "FILTER_VCF_AF ${sample_id}"
    label 'process_high'

    input:
    tuple val(sample_id), path(vcf), path(exome_vcf), path(exome_index), path(exome_bed)

    output:
    path "${sample_id}_final_filtered.vcf.gz"
    path "${sample_id}_final_filtered.vcf.gz.*"

    script:
    """
    # Compress and index the raw VCF
    bgzip -c ${vcf} > ${sample_id}_raw.vcf.gz
    tabix -p vcf ${sample_id}_raw.vcf.gz

    # Subset to target regions defined in the BED file
    bcftools view --threads ${task.cpus} -R ${exome_bed} ${sample_id}_raw.vcf.gz -Oz -o ${sample_id}_exome.vcf.gz
    tabix -p vcf ${sample_id}_exome.vcf.gz

    # Annotate with gnomAD allele frequency
    bcftools annotate --threads ${task.cpus} -a ${exome_vcf} -c 'INFO/gnomAD_AF:=AF' ${sample_id}_exome.vcf.gz -Oz -o ${sample_id}_annotated.vcf.gz
    tabix -p vcf ${sample_id}_annotated.vcf.gz

    # Normalise multiallelic sites before filtering
    bcftools norm --threads ${task.cpus} -m -any ${sample_id}_annotated.vcf.gz -Oz -o ${sample_id}_norm.vcf.gz
    tabix -p vcf ${sample_id}_norm.vcf.gz

    # Retain PASS variants with gnomAD AF < 0.05
    bcftools view --threads ${task.cpus} -f PASS -i 'INFO/gnomAD_AF<0.05' ${sample_id}_norm.vcf.gz -Oz -o ${sample_id}_final_filtered.vcf.gz
    bcftools index -f ${sample_id}_final_filtered.vcf.gz
    """
}
