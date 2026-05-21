#!/usr/bin/env nextflow
nextflow.enable.dsl = 2

include { VARIANT_CALLING } from './workflows/variant_calling'

workflow {
    VARIANT_CALLING()
}
