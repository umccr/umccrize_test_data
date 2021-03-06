import os
import shutil
import csv
from ngs_utils.bcbio import BcbioProject
from os.path import join, abspath, relpath, basename, dirname
from glob import glob
from ngs_utils.file_utils import splitext_plus


shell.executable(os.environ.get('SHELL', 'bash'))
shell.prefix('')  # Fixes Snakemake on Spartan

threads_max = 32


Rjn_HSAPIENS_DIR = '/g/data/gx8/local/development/bcbio/genomes/Hsapiens'
Rjn_KEY_GENES = '/g/data3/gx8/extras/vlad/synced/umccr/umccrise/umccrise/ref_data/generated/key_genes.txt'
Rjn_AZ300_BED = '/g/data3/gx8/extras/vlad/synced/umccr/umccrise/umccrise/ref_data/generated/key_genes.GRCh37.bed'

BCBIO_DIR = config.get('final', '/g/data3/gx8/extras/vlad/Analysis/bcbio_rnaseq/Tothill-CUP_WTS-merged/final')
run = BcbioProject(BCBIO_DIR)
sample_by_name = {s.name: s for s in run.samples}


SORT_SEED = "--random-source <(echo aaaaaaaaaaaaaaa)"


bcbio_copy_path = config.get('out', 'data/bcbio_test_project_rnaseq')
bcbio_copy_date = join(bcbio_copy_path, 'final', basename(run.date_dir))


rule all:
    input:
        join(bcbio_copy_date, 'multiqc', 'multiqc_report.html'),
        join(bcbio_copy_date, 'annotated_combined.counts'),
        join(bcbio_copy_date, 'tx2gene.csv'),
        expand(join(bcbio_copy_path, 'final', '{sample}', '{sample}.bam'), sample=sample_by_name),
        expand(join(bcbio_copy_path, 'final', '{sample}', '{sample}.bam.bai'), sample=sample_by_name),
        expand(join(bcbio_copy_path, 'final', '{sample}', 'salmon', 'quant.sf'), sample=sample_by_name)


rule annotated_counts:
    input:
        join(run.date_dir, 'annotated_combined.counts')
    output:
        join(bcbio_copy_date, 'annotated_combined.counts')
    shell:
        'head -n1 {input} > {output} && '
         'grep -w -f ' + Rjn_KEY_GENES + ' {input} >> {output}'


rule key_genes_ensg:
    input:
        filtered_counts_file = rules.annotated_counts.output[0]
    output:
        'work_snake/key_genes_ensg.txt'
    shell:
        'sed 1d {input} | cut -f1 > {output}'


rule tx2gene:
    input:
        tx2gene = join(run.date_dir, 'tx2gene.csv'),
        key_ensg = rules.key_genes_ensg.output[0]
    output:
        join(bcbio_copy_date, 'tx2gene.csv')
    shell:
        'grep -w -f {input.key_ensg} {input.tx2gene} > {output}'


rule subset_bam:
    input:
        bam = lambda wc: sample_by_name[wc.sample].bam,
        roi_bed = Rjn_AZ300_BED
    output:
        join(bcbio_copy_path, 'final', '{sample}', '{sample}-ready.bam')
    params:
        sort_prefix = 'snake_work/{sample}/sort_prefix'
    threads:
        threads_max
    shell:
        'samtools view -@ {threads} {input.bam} -L {input.roi_bed} -h | '
        'samtools sort -@ {threads} -T {params.sort_prefix} -O bam -o {output}'


rule index_bam:
    input:
        join(bcbio_copy_path, '{sample}', '{sample}-ready.bam')
    output:
        join(bcbio_copy_path, '{sample}', '{sample}-ready.bam.bai')
    shell:
        'samtools index {input}'


rule quant_sf:
    input:
        qsf = join(run.final_dir, '{sample}', 'salmon', 'quant.sf'),
        tx2gene = join(bcbio_copy_date, 'tx2gene.csv')
    output:
        join(bcbio_copy_path, 'final', '{sample}', 'salmon', 'quant.sf')
    shell:
        'head -n1 {input.qsf} > {output} && '
        'grep -f <(cut -d "," -f1 {input.tx2gene}) {input.qsf} >> {output}'


rule rsync_project:
    input:
        project_ori_final = run.final_dir,
        project_ori_config = run.config_dir
    output:
        join(bcbio_copy_date, 'multiqc', 'multiqc_report.html')
    params:
        project_copy = bcbio_copy_path
    shell:
        'rsync -tavz {input.project_ori_config} {params.project_copy}'
        ' && rsync -tavz'
        ' --exclude ".snakemake/"'
        ' --exclude "umccrised/"'
        ' --exclude "test/"'
        ' --include "*/"'
        ' --include "multiqc_report.html"'
        ' --include "multiqc_list_files.txt"'
        ' --include "list_files_final.txt"'
        ' --include "multiqc_config.yaml"'
        ' --include "multiqc_config.yaml"'
        ' --include "data_versions.csv"'
        ' --include "project-summary.yaml"'
        ' --include "programs.txt"'
        ' --include "bcbio-nextgen-commands.log"'
        ' --include "bcbio-nextgen.log"'
        ' --exclude "*"'
        ' {input.project_ori_final} {params.project_copy}'


# rule populate_sample:
#     input:
#         bam = rules.subset_bam.output[0],
#         bai = rules.index_bam.output[0],
#         quant_sf = rules.quant_sf.output[0],
#         bcbio_copy_path = rules.rsync_project.output[0]
#     output:
#         bcbio_copy_path + '/.populated_{batch}.done'
#     run:





