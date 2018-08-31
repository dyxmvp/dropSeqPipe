"""Filter data"""

#Which rules will be run on the host computer and not sent to nodes
localrules: clean_cutadapt, plot_adapter_content, multiqc_trimmomatic

rule cutadapt_R1:
    input:
        R1='data/{sample}_R1.fastq.gz',
        adapters=config['FILTER']['cutadapt']['adapters-file']
    output:
        fastq=temp("data/{sample}/trimmmed_R1.fastq.gz")
    params:
        cell_barcode_length=config['FILTER']['cell-barcode']['end'] - config['FILTER']['cell-barcode']['start'] + 1,
        barcode_length=config['FILTER']['UMI-barcode']['end'] - config['FILTER']['cell-barcode']['start'] + 1,
        extra_params = config['FILTER']['cutadapt']['R1']['extra-params'],
        max_n=config['FILTER']['cutadapt']['R1']['maximum-Ns'],
        barcode_quality=config['FILTER']['cutadapt']['R1']['quality-filter']
    threads: 10
    log:
        qc="logs/cutadapt/{sample}_R1.qc.txt"
    conda: '../envs/cutadapt.yaml' 
    shell:
        """cutadapt --max-n {params.max_n}\
        -a file:{input.adapters}\
        -g file:{input.adapters}\
        -q {params.barcode_quality},{params.barcode_quality}\
        --minimum-length {params.barcode_length}\
        --cores={threads}\
        -o {output.fastq}\
        --overlap {params.cell_barcode_length}\
        {params.extra_params}\
        {input.R1}\
        > {log.qc}"""

rule cutadapt_R2:
    input:
        R2='data/{sample}_R2.fastq.gz',
        adapters=config['FILTER']['cutadapt']['adapters-file']
    output:
        fastq=temp("data/{sample}/trimmmed_R2.fastq.gz")
    params:
        extra_params=config['FILTER']['cutadapt']['R2']['extra-params'],
        read_quality=config['FILTER']['cutadapt']['R2']['quality-filter'],
        minimum_length=config['FILTER']['cutadapt']['R2']['minimum-length'],
        adapters_minimum_overlap=config['FILTER']['cutadapt']['R2']['minimum-adapters-overlap']
    threads: 10
    log:
        qc="logs/cutadapt/{sample}_R2.qc.txt"
    conda: '../envs/cutadapt.yaml' 
    shell:
        """cutadapt -a file:{input.adapters} -g file:{input.adapters} -q {params.read_quality} --minimum-length {params.minimum_length} --cores={threads} -o {output.fastq} {input.R2} {params.extra_params} --overlap {params.adapters_minimum_overlap} > {log.qc}"""

rule clean_cutadapt:
    input:
        R1="logs/cutadapt/{sample}_R1.qc.txt",
        R2="logs/cutadapt/{sample}_R2.qc.txt"
    output:
        "logs/cutadapt/{sample}.clean_qc.csv"
    script:
        '../scripts/clean_cutadapt.py'



rule repair:
    input:
        R1='data/{sample}/trimmmed_R1.fastq.gz',
        R2='data/{sample}/trimmmed_R2.fastq.gz'
    output:
        R1='data/{sample}/trimmmed_repaired_R1.fastq.gz',
        R2='data/{sample}/trimmmed_repaired_R2.fastq.gz'
    log:
        'logs/bbmap/{sample}_repair.txt'
    conda: '../envs/bbmap.yaml'
    params:
        memory=config['LOCAL']['memory']
    shell:
        """repair.sh -Xmx{params.memory} in={input.R1} in2={input.R2} out1={output.R1} out2={output.R2} repair=t 2> {log}"""


rule plot_adapter_content:
    input:
        expand('logs/cutadapt/{sample}.clean_qc.csv', sample=samples.index)
    params:
        Cell_length=config['FILTER']['cell-barcode']['end'] - config['FILTER']['cell-barcode']['start'] + 1,
        UMI_length=config['FILTER']['UMI-barcode']['end'] - config['FILTER']['UMI-barcode']['start'] + 1,
        sample_names=lambda wildcards: samples.index,
        batches=lambda wildcards: samples.loc[samples.index, 'batch']
    conda: '../envs/plots.yaml'
    output:
        pdf='plots/adapter_content.pdf'
    script:
        '../scripts/plot_adapter_content.R'

rule multiqc_trimmomatic:
    input:
        expand('logs/cutadapt/{sample}_R1.qc.txt', sample=samples.index)
    params: '-m cutadapt'
    output:
        html='reports/filter.html'
    wrapper:
        '0.27.1/bio/multiqc'