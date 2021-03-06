Test data for umccrise
----------------------------------------------------------------------------

```
normal: CCR180074_WH18B001P017
batch: 2016.249.18.WH.P017_1 - tumor: CCR180074_WH18B001P017
batch: 2016.249.18.WH.P017_2 - tumor: CCR180159_VPT-WH017A
```

## Generating test data

Install dependencies for generating test data:

```
conda install -c bioconda pybedtools sambamba tabix snakemake-minimal
```

Run on a bcbio-nextgen WGS project:

```
snakemake -p Snakefile.prep_test_data --config \
    final=/data/cephfs/punim0010/data/Results/Avner/2018-12-05/final \
    out=data/bcbio_test_project \
    sample=CCR170093_MHP013_O,CCR180137_VPT-WH23
```

Or on RNAseq WTS project:

```
snakemake -p Snakefile.prep_test_data_rnaseq --config \
    final=final \
    out=data/bcbio_test_project_rnaseq
```

## Testing

```
nosetest -s test.py
```

