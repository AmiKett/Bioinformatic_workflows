/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
include { paramsSummaryMap       } from 'plugin/nf-schema'
include { softwareVersionsToYAML } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { FASTQC } from '../modules/nf-core/fastqc/main'
include { TRIMGALORE } from '../modules/nf-core/trimgalore/main'
include { STAR_ALIGN } from '../modules/nf-core/star/align/main'
include { SALMON_QUANT } from '../modules/nf-core/salmon/quant/main'
include { DUPRADAR } from '../modules/nf-core/dupradar/main'
include { QUALIMAP_RNASEQ } from '../modules/nf-core/qualimap/rnaseq/main'
include { MULTIQC } from '../modules/nf-core/multiqc/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow SEMINAR {

    take:
    ch_samplesheet // channel: samplesheet read in from --input
    main:

    ch_multiqc_files = channel.empty()

    ch_star_index = params.star_index ? channel.value(tuple([id: 'star_index'], file(params.star_index, checkIfExists: true))) : channel.empty()
    ch_gtf = params.gtf ? channel.value(tuple([id: 'annotation'], file(params.gtf, checkIfExists: true))) : channel.empty()
    ch_salmon_index = params.salmon_index ? channel.value(file(params.salmon_index, checkIfExists: true)) : channel.empty()
    ch_transcriptome = params.transcriptome ? channel.value(file(params.transcriptome, checkIfExists: true)) : channel.empty()
    ch_star_ignore_sjdbgtf = channel.value(params.star_ignore_sjdbgtf ?: false)
    ch_salmon_alignment_mode = channel.value(params.salmon_alignment_mode ?: false)
    ch_salmon_lib_type = channel.value(params.salmon_lib_type ?: false)

    ch_multiqc_config = params.multiqc_config ? channel.fromPath(params.multiqc_config, checkIfExists: true) : channel.value([])
    ch_multiqc_extra_config = params.multiqc_extra_config ? channel.fromPath(params.multiqc_extra_config, checkIfExists: true) : channel.value([])
    ch_multiqc_logo = params.multiqc_logo ? channel.fromPath(params.multiqc_logo, checkIfExists: true) : channel.value([])
    ch_multiqc_replace_names = params.multiqc_replace_names ? channel.fromPath(params.multiqc_replace_names, checkIfExists: true) : channel.value([])
    ch_multiqc_sample_names = params.multiqc_sample_names ? channel.fromPath(params.multiqc_sample_names, checkIfExists: true) : channel.value([])

    // FASTQC input: sample sheet
    FASTQC(ch_samplesheet)

    // TRIMGALORE input: sample sheet
    TRIMGALORE(ch_samplesheet)

    // STAR_ALIGN input: trimmed reads, STAR index, GTF, ignore-GTF flag
    STAR_ALIGN(
        TRIMGALORE.out.reads,
        ch_star_index,
        ch_gtf,
        ch_star_ignore_sjdbgtf
    )

    // SALMON_QUANT input: trimmed reads, SALMON index, GTF, transcriptome, alignment mode, library type override
    SALMON_QUANT(
        TRIMGALORE.out.reads,
        ch_salmon_index,
        ch_gtf.map { _meta, gtf -> gtf },
        ch_transcriptome,
        ch_salmon_alignment_mode,
        ch_salmon_lib_type
    )

    // DUPRADAR input: alignment BAM, GTF
    DUPRADAR(
        STAR_ALIGN.out.bam,
        ch_gtf
    )

    // QUALIMAP_RNASEQ input: alignment BAM, GTF
    QUALIMAP_RNASEQ(
        STAR_ALIGN.out.bam,
        ch_gtf
    )

    // MultiQC files channel populated from relevant module outputs
    ch_multiqc_files = ch_multiqc_files
        .mix(FASTQC.out.zip.map { _meta, zip -> zip })
        .mix(TRIMGALORE.out.zip.map { _meta, zip -> zip })
        .mix(TRIMGALORE.out.log.map { _meta, log -> log })
        .mix(STAR_ALIGN.out.log_final.map { _meta, log -> log })
        .mix(SALMON_QUANT.out.results.map { _meta, results -> results })
        .mix(DUPRADAR.out.multiqc.map { _meta, mqc -> mqc })
        .mix(QUALIMAP_RNASEQ.out.results.map { _meta, results -> results })

    MULTIQC(
        ch_multiqc_files.collect(),
        ch_multiqc_config,
        ch_multiqc_extra_config,
        ch_multiqc_logo,
        ch_multiqc_replace_names,
        ch_multiqc_sample_names
    )
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
