# High-energy Physics Analysis Queries in JSONiq/Rumble

This repository contains implementations of High-energy Physics (HEP) analysis queries from [the IRIS HEP benchmark](https://github.com/iris-hep/adl-benchmarks-index) written in [JSONiq](https://www.jsoniq.org/) to be run on [Rumble](https://rumbledb.org).

## Motivation

The purpose of this repository is to study the suitability of JSONiq for HEP analyses and to serve as a use case for improving Rumble. While JSONiq has been originally designed for dealing with JSON documents, we believe that it might be suited for HEP analyses as well. Compared to many existing HEP tools, it is a higher-level language that separates the logic of the analyses from how data is stored and how the query is executed more (which has many advantages, but also some disadvantages). Compared to SQL it has better support for the nestedness of both data and queries typically found in HEP and is standardized and hence portable across different JSONiq implementations.

## Query Implementations

There are currently two sets of implementations: an *index-based* (stored in [`queries/index-based/`](queries/index-based/) and an *object-based* one (stored in [`queries/object-based/`](queries/object-based/)). The index-based implementation directly manipulates the columnar data model as it is typically exposed by existing HEP tools and which corresponds how data is physically stored in ROOT files. For example, computing the invariant mass looks loke [this](queries/common/hep-i.jq), using `$i` and `$j` to extract `eta`, `phi`, and `pt` from two events:

```xquery
let $eta-diff := $event.Muon_eta[[$i]] - $event.Muon_eta[[$j]]
let $phi-diff := $event.Muon_phi[[$i]] - $event.Muon_phi[[$j]]
let $cosh := (exp($eta-diff) + exp(-$eta-diff)) div 2
let $invariant-mass :=
  2 * $event.Muon_pt[[$i]] * $event.Muon_pt[[$j]] * ($cosh - cos($phi-diff))
return $invariant-mass
```

The object-based implementation restructures each event first by constructing the objects from its values in the different columns. The same computation then looks like [this](queries/common/query.jq):

```xquery
  2 * $m1.pt * $m2.pt * (math:cosh($m1.eta - $m2.eta) - cos($m1.phi - $m2.phi))
```

While this is clearly more readable, the restructuring may have an overhead and access data that is in fact not needed. However, due to the high-level nature of JSONiq, it is possible to eliminate both; this is in fact a standard feature of SQL optimizers and the same techniques can be applied to JSONiq. Finally, it may be possible to read the data directly as objects even from columnar data, as it is common to do for example with [Parquet](https://parquet.apache.org/) (in which case it is also possible and common to load only the required data from file).

## Prerequisites

* [Docker](https://docs.docker.com/engine/install/) or an installation of Rumble (see its [documentation](https://rumble.readthedocs.io/en/latest/Getting%20started/))
* Python 3 with pip

## Setup

1. Install the Python requirements:
   ```bash
   pip3 install -r requirements.txt
   ```
1. Configure `rumble.sh` or `start-server.sh`. The simplest is to copy the provided files that use docker:
   ```bash
   cp rumble.docker.sh rumble.sh
   cp start-server.docker.sh start-server.sh
   ```
   Alternatively, copy the `*.local.sh` variants and modify them to contain the correct paths.
1. If you want to use a long-running Rumble server, start it:
   ```bash
   ./start-server.sh
   ```

## Data

The benchmark defines the queries against the following data set:

```
root://eospublic.cern.ch//eos/root-eos/benchmark/Run2012B_SingleMu.root
```

For getting started quickly, we provide two samples of the file converted to Parquet are included in [`data/`](/data/). Since Rumble supports [reading ROOT files directly](https://rumble.readthedocs.io/en/latest/Input/#root), doing so only requires a minimal change in the query implementations.

### Local Processing

Instead of processing the file in-place through the `root://` protocol, you may download it to local storage using [`xrdcp`](https://linux.die.net/man/1/xrdcp) (which you can install by [installing the ROOT framework](https://root.cern/install/)).

### Extracting a Sample

In order to extract a samle for faster processing, you can use `rooteventselector` and its `-f` and `-l` flags (which is part of the ROOT framework as well).

### Converting to Parquet

You may convert the ROOT files into Parquet (or other formats) using `tools/root2parquet.py`. This downloads the specified package from the internet, so if you are behind a proxy, follow [this](https://stackoverflow.com/a/36676963).

```bash
spark-submit \
    --packages edu.vanderbilt.accre:laurelin:1.1.1 \
    tools/root2parquet.py \
        -i data/Run2012B_SingleMu.root \
        -0 data/Run2012B_SingleMu.parquet
```

### Naming Convention for this Implementation

`test_queries.py` looks for the input files in `data/` with names of the form `Run2012B_SingleMu{suffix}.parquet`, where `{suffix}` is empty for the full data set and `-{num_events}` for a sample of `{num_events}`. It also looks for reference results in `queries/{query_name}/ref{suffix}.csv` with the same `{suffix}`. It also looks for reference results in `queries/{query_name}/ref{suffix}.csv` with the same `{suffix}`..

## Running Queries

Run all queries on the full data set using `rumble.sh` from above with the following command:

```bash
./test_queries.py -v
```

Run following to see more options

```
$ ./test_queries.py --help
usage: test_queries.py [options] [file_or_dir] [file_or_dir] [...]

...
custom options:
  -Q QUERY_ID, --query-id=QUERY_ID
                        Folder name of query to run.
  -N NUM_EVENTS, --num-events=NUM_EVENTS
                        Number of events taken from the input file. This influences which reference file should be taken.
  -I INPUT_PATH, --input-path=INPUT_PATH
                        Path to input ROOT file.
  --rumble-cmd=RUMBLE_CMD
                        Path to spark-submit.
  --rumble-server=RUMBLE_SERVER
                        Rumble server to connect to.
  --freeze-result       Overwrite reference result.
  --plot-histogram      Plot resulting histogram as PNG file.
...
```

For example, to run all queries containing `object-based` on the test data set with 150 events using a local server, do the following:

```bash
./test_queries.py -v -N 150 --rumble-server http://localhost:8001/jsoniq -k object-based
```

## Known Issues

It may be the case that the following errors are encountered during the execution of the queries:

* `Spark java.lang.OutOfMemoryError: Java heap space` - In this case, it is suggested that the `spark.driver.memory` and `spark.executor.memory` are increased, for example to `8g` and `4g` respectively. These should be set in `<spark_install_dir>/conf/spark-defaults.conf`. 
* `Buffer overflow. Available: 0, required: xxx` - In this case, the issue likely stems from the Kryo framework. It is suggested that the `spark.kryoserializer.buffer.max` be set to something like `1024m`. This should be set in `<spark_install_dir>/conf/spark-defaults.conf`. 
