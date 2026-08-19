nextflow.enable.dsl = 2

include { MERGE_SNP_INDEL  } from '../modules/local/merge_snp_indel'
include { NORMALIZE_VCF    } from '../modules/local/normalize_vcf'
include { ANNOTATE_VCF     } from '../modules/local/annotate_vcf'
include { FILTER_AF        } from '../modules/local/filter_af'
include { FILTER_BY_GENES  } from '../modules/local/filter_by_genes'

workflow ANNOTATION_FILTERING {

    if (!params.vcf_dir) error "ERROR: --vcf_dir is required"
    if (!params.reference_fasta)       error "ERROR: --reference_fasta is required (needed to left-align indels in NORMALIZE_VCF)"
    if (!params.reference_fasta_index) error "ERROR: --reference_fasta_index is required (needed to left-align indels in NORMALIZE_VCF)"

    // Fail fast if none of the known source folders contain any VCFs
    def source_dirs = ['VCF_NOVOGENE', 'VCF_NEXT', 'VCF_CEGAT'].collect { file("${params.vcf_dir}/${it}") }
    def total_vcfs = source_dirs
        .findAll { it.exists() }
        .collect { dir -> dir.listFiles().findAll { it.name ==~ /.*\.vcf(\.gz)?$/ } }
        .flatten()
    if (total_vcfs.isEmpty()) {
        error "ERROR: No VCF files found in VCF_NOVOGENE/, VCF_NEXT/ or VCF_CEGAT/ under ${params.vcf_dir}"
    }

    // VCF_NEXT and VCF_CEGAT: one VCF per sample, ready to normalise directly.
    simple_vcfs = Channel
        .fromPath(["${params.vcf_dir}/VCF_NEXT/*.vcf.gz", "${params.vcf_dir}/VCF_CEGAT/*.vcf.gz"])
        .map { vcf -> tuple(vcf.getSimpleName(), vcf) }

    // VCF_NOVOGENE: SNPs and Indels are split per sample
    // (e.g. D10017772.GATK.snp.vcf.gz / D10017772.GATK.indel.vcf.gz)
    // The sample_id is everything before ".GATK.snp/indel.vcf.gz" — filenames
    // must match exactly except for that snp/indel token, so grouping never
    // silently drifts into matching the wrong person's files.
    novogene_pairs = Channel
        .fromPath("${params.vcf_dir}/VCF_NOVOGENE/*.vcf.gz")
        .map { vcf ->
            def m = (vcf.getName() =~ /^(.+)\.GATK\.(snp|indel)\.vcf\.gz$/)
            if (!m.matches()) {
                error "ERROR: unexpected NOVOGENE filename '${vcf.getName()}' — expected '<sample_id>.GATK.snp.vcf.gz' or '<sample_id>.GATK.indel.vcf.gz'"
            }
            tuple(m[0][1], m[0][2], vcf)
        }
        .groupTuple()
        .map { sample_id, types, vcfs ->
            // A sample should have at most one snp file and one indel file.
            // A replacement upload must overwrite the old file, not sit next to it —
            // so anything else here means leftover/duplicate files that need cleanup.
            if (types.size() > 2 || (types.size() == 2 && types.toSet().size() == 1)) {
                error "ERROR: unexpected NOVOGENE files for sample '${sample_id}' — found ${types} (${vcfs}). Expected exactly one snp file and one indel file; remove any duplicate/leftover files."
            }
            if (types.size() == 1) {
                log.warn "WARNING: NOVOGENE sample '${sample_id}' has only a '${types[0]}' file — merging/proceeding with this single file (no ${types[0] == 'snp' ? 'indel' : 'snp'} counterpart found)."
            }
            tuple(sample_id, vcfs)
        }

    novogene_vcfs = MERGE_SNP_INDEL(novogene_pairs)

    vcf_channel = simple_vcfs.mix(novogene_vcfs)

    // Gene list: explicit param takes precedence, otherwise expect genes.txt in vcf_dir.
    // Empty file → no filtering (handled inside FILTER_BY_GENES).
    gene_list = params.gene_list ? file(params.gene_list) : file("${params.vcf_dir}/genes.txt")

    // Module 1 – normalise multiallelic sites and left-align indels
    normalized = NORMALIZE_VCF(vcf_channel, file(params.reference_fasta), file(params.reference_fasta_index))

    // Module 2 – annotate with gnomAD AF
    annotated = ANNOTATE_VCF(normalized, file(params.exome_vcf), file(params.exome_index))

    // Module 3 – retain PASS variants with gnomAD AF < 0.05
    filtered = FILTER_AF(annotated)

    // Module 4 – filter by gene list (skipped if txt is empty)
    FILTER_BY_GENES(filtered, gene_list)
}
