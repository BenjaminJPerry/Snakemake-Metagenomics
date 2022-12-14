# 2022 Alex Kim
# Maintainer: Alex Kim
# Email: alex.kim@agresearch.co.nz


# configfile: 

import os

onstart:
    print(f"Working directory: {os.getcwd()}")
    print("TOOLS: ")
    os.system('echo "  bash: $(which bash)"')
    os.system('echo "  PYTHON: $(which python)"')
    os.system('echo "  CONDA: $(which conda)"')
    os.system('echo "  SNAKEMAKE: $(which snakemake)"')
    os.system('echo "  PYTHON VERSION: $(python --version)"')
    os.system('echo "  CONDA VERSION: $(conda --version)"')
    print(f"Env TMPDIR={os.environ.get('TMPDIR', '<n/a>')}")

# define samples from data directory using wildcards
SAMPLES, = glob_wildcards('fastq/{samples}.fastq.gz')

# sanity check
print("Found: ")
for WLDCRD in SAMPLES:
    print(WLDCRD)
print("")

rule all:
    input: 
        # kraken2 report 
        # multiqc reports (raw data and knead data)
        'results/ReadsMultiQCReportRAWDATA.html',
        'results/ReadsMultiQCReportKNEADDATA.html'
        

rule fastqc:
    # quality control 
    input:
        fastq = 'fastq/{samples}.fastq.gz' # process each sample individually 
    output: 
        html = 'results/fastqc/{samples}_fastqc.html',
        zip = 'results/fastqc/{samples}_fastqc.zip'
    conda: 
        'envs/fastqc.yaml'
    threads: 1 
    message: 
        'Running quality checks on reads: {wildcards.samples}\n'
    shell:
        'fastqc '
        '-o results/fastqc/ '
        '-q ' # suppress progress messages; only report errors 
        '-t {threads} '
        '{input.fastq}'


rule multiqc:
    # reporting tool 
    input: 
        fastqc = expand('results/fastqc/{samples}_fastqc.zip', samples = SAMPLES) # input all outputs from fastqc as one input 
    output: 
        multiqc = 'results/ReadsMultiQCReportRAWDATA.html'
    conda: 
        "envs/multiqc.yaml"
    shell:
        'multiqc '
        '-n results/ReadsMultiQCReport '
        '-s ' # to not clean sample names 
        '-f ' # overwrite existing reports 
        '--interactive ' # interactive plots 
        '{input.fastqc}'


rule kneaddata: 
    # quality control - separate bacterial reads from contaminant reads (host, bacterial 16S sequences) 
    input: 
        ### two inputs for paired end reads? ###
        reads = 'fastq/{samples}.fastq.gz'
    output: 
        # trim adapters ...
        trimReads = temp('results/kneaddata/{samples}_kneaddata.trimmed.fastq'),
        # trim repetitive sequences 
        trfReads = temp('results/kneaddata/{samples}_kneaddata.repeats.removed.fastq'),
        # trim host DNA 
        ovineReads = temp('results/kneaddata/{samples}_kneaddata_ARS_UI_Ramb_v2_bowtie_contam.fastq'),
        # trim 16S rRNA
        silvaReads = temp('results/kneaddata/{samples}_kneaddata_SILVA_128_LSUParc_SSUParc_ribosomal_RNA_bowtie2_contam.fastq'),
        # filtered reads 
        cleanReads = 'results/kneaddata/{samples}_kneaddata.fastq',
        # summary?
        readStats = 'results/kneaddata/{samples}.read.stats.txt'
    conda: 
        'biobakery'
    log:
        'logs/{samples}.kneaddata.log'
    threads: 4
    message:
        'kneaddata: {wildcards.samples}\n'
    shell:
        'kneaddata '
        '--input {input.reads} '
        '-t {threads}'
        '--log-level INFO '
        '--log {log} '
        '--trimmomatic /home/kima/conda-envs/biobakery/share/trimmomatic-0.39-2 ' 
        '--sequencer-source TruSeq3 ' # to identify adapter sequences? 
        '-db ref/ARS_UI_Ramb_v2 '
        '-db ref/SILVA_128_LSUParc_SSUParc_ribosomal_RNA '
        '-o results/kneaddata && '
        'seqkit stats -j 12 -a results/kneaddata/{wildcards.samples}*.fastq > {output.readStats}'


rule fastqcKDRs: 
    input: 
        KDRs = rules.kneaddata.output.cleanReads
    output:
        'results/fastqcKDR/{samples}_kneaddata_fastqc.zip'
    conda: 
        'fastqc'
    threads: 1
    message: 
        'Running quality checks on reads: {wildcards.samples}\n'
    shell: 
        'fastqc '
        '-o results/fastqcKDR/ '
        '-q '
        '-t {threads} '
        '{input.fastqc}'

        
rule kraken2:
    # taxonomic profiling 

rule braken:
    # compute abundance 

#  merge kraken2 reports using utility scripts 