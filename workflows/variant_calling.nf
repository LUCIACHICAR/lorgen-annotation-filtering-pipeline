nextflow.enable.dsl = 2

include { BWA_INDEX       } from '../modules/local/bwa_index'
include { MERGE_LANES     } from '../modules/local/merge_lanes'
include { ALIGN_READS     } from '../modules/local/align_reads'
include { SORT_BAM        } from '../modules/local/sort_bam'
include { MARK_DUPLICATES } from '../modules/local/mark_duplicates'
include { INDEX_BAM       } from '../modules/local/index_bam'
include { FASTQC          } from '../modules/local/fastqc'
include { MULTIQC         } from '../modules/local/multiqc'
include { CALL_VARIANTS   } from '../modules/local/call_variants'
include { FILTER_VCF_AF   } from '../modules/local/filter_vcf_af'

workflow VARIANT_CALLING {

    if (!params.reads_dir)    error "ERROR: --reads_dir is required"
    if (!params.genome_fasta) error "ERROR: --genome_fasta is required"
    if (!params.exome_vcf)    error "ERROR: --exome_vcf is required"
    if (!params.exome_index)  error "ERROR: --exome_index is required"
    if (!params.exome_bed)    error "ERROR: --exome_bed is required"

    genome       = file(params.genome_fasta)
    genome_index = BWA_INDEX(genome)
        .collect()
        .map { idx_files -> tuple(genome, idx_files.sort()) }

    samples = Channel
        .fromPath("${params.reads_dir}/*_L001_R1_001.fastq.gz")
        .map { it.getName().replaceAll(/_L001_R1_001\.fastq\.gz$/, '') }
        .unique()

    merged_reads = samples
        .map { sample_id -> tuple(sample_id, params.reads_dir) }
        | MERGE_LANES

    aligned_inputs = merged_reads.combine(genome_index)
    aligned_bams   = ALIGN_READS(aligned_inputs)

    FASTQC(aligned_bams.map { sid, bam -> tuple("${sid}_aligned", bam) })

    sorted_bams  = SORT_BAM(aligned_bams)
    dedup_bams   = MARK_DUPLICATES(sorted_bams)
    indexed_bams = INDEX_BAM(dedup_bams.map { sid, bam, _ -> tuple(sid, bam) })

    FASTQC(dedup_bams.map { sid, bam, _ -> tuple("${sid}_dedup", bam) })

    variants = indexed_bams
        .combine(Channel.value(genome))
        .map { sid, bam, bai, ref -> tuple(sid, bam, bai, ref) }
        | CALL_VARIANTS

    filtered_vcfs = variants.map { sid, vcf ->
        tuple(sid, vcf, file(params.exome_vcf), file(params.exome_index), file(params.exome_bed))
    } | FILTER_VCF_AF

    fastqc_files = FASTQC.out
        .map { sid, zip, html -> [zip, html] }
        .flatten()
        .collect()

    MULTIQC(fastqc_files)
}
