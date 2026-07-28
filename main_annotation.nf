#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { ANNOTATION_FILTERING } from './workflows/annotation_filtering'

workflow {
    ANNOTATION_FILTERING()
}
