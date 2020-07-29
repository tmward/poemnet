# POEMNet
Repository holds software used in
[Automated operative phase identification in peroral endoscopic myotomy](https://doi.org/10.1007/s00464-020-07833-9).
In particular, it houses the scripts used to generate the statistics and
visualizations used in the Results section of the paper. Documentation
for the scripts includes heavy commenting within each script, an
informative commit message per script, and the below README. If you
still have any questions, please reach out to me!

## Requirements

### Python
Python >= 3.6 required. The following extra packages will be needed for
some of the scripts. Install through your distribution's package
manager/PyPI/etc.

1. `docopt` (verified to work with version `0.6.2_5`)

### R
All calculations for the paper were performed with R 3.6. The
following packages will also be required (recommend adding with
`install.packages()`)

1. `tidyverse` (verified to work with version `1.3.0`)
2. `irr` (verified to work with version `0.84.1`)
3. `caret` (verified to work with version `6.0-86`)
4. `docopt` (verified to work with version `0.6.1`)

### Other
The `video_lengths.py` script will require ``ffprobe`` which is
typically packaged with ``ffmpeg``.

# Video statistics
The following sections address how to calculate the results shared in
the Results subsection *Video information* of the paper.

## Overall videos' duration statistics
To calculate the mean, min, max, median, and pstdev on the overall
lengths of a directory full of videos, use `video_lengths.py`. Results
are output to `stdout` in unit of seconds, rounded to two decimal
places. Of note, this will require
[`ffprobe`](https://ffmpeg.org/ffprobe.html).

### Example
```
video_lengths.py /data/directory_holding_videos
``` 
will output:
```
For the videos in '/data/directory_holding_videos', in seconds:
The mean is: 1467.5
The pstdev is: 645.5
The min is: 822
The median is: 1467.5
The max is: 2113
```

## Phase duration statistics
Phase duration statistics are calculated from annotated ground truth,
with one annotation per video. Our annotation file format, due to
historical reasons, are all converted to the
[Anvil](http://www.anvil-software.org/) file format, which is in xml.

All statistics, though, are calculated from a csv file (detailed in
section below). Therefore to generate statistics and the boxplot of
phase duration, if your annotations are in anvil format, I provide
scripts to convert that information into a csv of the correct structure.
Otherwise if you stored your data in another format, I recommend
skipping the headache of your annotation format -> Anvil -> CSV and
instead write a program to generate a CSV directly from your annotation
format. If you need help with this, please reach out to me! Happy to
offer guidance and/or write a script.

### `phase_duration.csv` structure
The below table shows the general structure of the CSV that contains
annotated ground truth for an entire set of videos:

| **variable** | **class** | **description** |
|:--|:--|:------------|
| video | character | Filename of video annotated |
| frame | double | Frame number for the video. Starts at 0. Equivalent to seconds for this case | 
| annotator | character | Annotation for each frame (eg clip, cut, or NA if not annotated) done by the annotator generically named "annotator." Any column variable name is fine.|

### Make `phase_duration.csv` from anvil annotations
1. Into a directory (eg `annotations_dir`), move a single Anvil format
   annotation per video in the dataset
    - It is ok if the "coder" field in the anvil annotation has
      different annotator names, the next step will standardize these
2. Rename all "coder" fields in the anvil annotation files to "annotator"

    ```
    make_anvil_same_annotator.py annotations_dir standardized_name_dir
    ```
3. Generate `phase_duration.csv`

    ```
    anvil_to_frame_csv.py 1 standardized_name_dir phase_duration.csv
    ```
    - the `1` tells the script to generate only one row (aka frame) per
      second.

### Make a `phase_factors.csv`
Phase names in annotation files are typically abbreviated (eg
`muc_incis`) rather than there full human-readable name (eg
"Mucostomy"). Analysis programs also tend to order them alphabetically
in the display (eg "Mucostomy" will occur before "Submucosal
Injection"), which does not make sense as we would prefer the phases to
be temporally ordered. To fix both these issues, the statistics script
is fed a simple csv (`phase_factors.csv`) that specifies a short to full
name translation. In addition, the rows' order matters, so the first
row will be displayed first, and the last row will be displayed last in
any future graphs. You can use this to order your phases temporally for
example or any other arbitrary sorting.

The `phase_factors.csv` has the following structure:

| **variable** | **class** | **description** |
|:--|:--|:------------|
| `name` | character | Variable name used for the annotated phase in the annotation file, eg `mucos_close`|
| `full_name`| character | Full human readable name of the phase, eg "Mucosotomy Closure"|

An example `phase_factors.csv` for POEM is present in the `examples/`
directory.

### Generate statistics and plot
The script `overall_phase_stats.R` is used. It will generate a TSV with
the following summary statistics for each phase:

1. mean
2. sd (standard deviation)
3. min
4. Q1 (1st quartile)
5. med (median)
6. Q3 (3rd quartile)
7. max 
8. mad (median absolute deviation)

It can optionally generate a boxplot. With the command, you can
optionally invoke the time scale to be logarithmic. Phases will
be displayed on the Y-axis in the order they are specified in the
`phase_factors.csv`. Images output format (eg png, jpg, pdf) is
automatically inferred from the specified file extension given. In
general, `pdf` will provide the best image format (text will look the
best upon import into LaTeX). You can also specify the height and width
of the output boxplot. Below is an example invocation that outputs a TSV
with summary statistics in `durations.tsv` and a boxplot `boxplot.png`
that is a 12x8 cm image with a log scale for the time axis:

```
overall_phase_stats.R -f phase_factors.csv -o durations.tsv \
    -p -l 12 8 boxplot.png phase_duration.csv 
```

Invoking `overall_phase_stats.R -h` will print to stdout a help
message explaining all the command line options.

# Inter-annotator stats
The following sections address how to calculate the results in the
Results subsection *Inter-annotator reliability and agreement*.

As with the **Phase duration statistics** above, all statistics are
calculated from a csv file that holds all the annotations (detailed in
section below). Therefore to generate inter-annotator statistics, you
can either go from Anvil annotations to generate the csv (instructions
below) or generate it from your own annotations. If you need help with
that, please let me know!

## `multiple_annotator.csv` structure
The below table shows the general structure of the CSV that contains
annotated ground truth for an entire set of videos by multiple
annotators. Note, it is nearly identical to the csv `phase_duration.csv`
except that it can hold an infinite number of annotator name columns:

| **variable** | **class** | **description** |
|:---|:--|:------------|
| `video` | character | Filename of video annotated |
| `frame` | double | Frame number for the video. Starts at 0. Equivalent to seconds for this case | 
| `annotator_1's name` | character | Annotation for each frame (eg clip, cut, or NA if not annotated) done by the first annotator.|
| `annotator_2's name` | character | Annotation for each frame (eg clip, cut, or NA if not annotated) done by the second annotator.|
| `annotator_N's name` | character | Annotation for each frame (eg clip, cut, or NA if not annotated) done by the nth annotator.|

## Make `multiple_annotator.csv` from anvil annotations
1. Create a directory and move the annotations for a set of videos by
   multiple annotators into the directory
    - We have included the annotations performed by `DAH`, `ORM`, and
      `tmw` in the `examples/multiple_annotator_annotations` directory
    - Note that you will need each annotator's name in the anvil xml
      file to be the same between files (eg do not have TMW in one and
      TW in the other, this will count as different annotators)
    - Also, each video must be annotated by **all annotators** otherwise
      the csv generation script may not output correctly
2. Generate the `multiple_annotator.csv` from the annotations stored in
   the directory `multiple_annotator_annotations`

    ```
    anvil_to_frame_csv.py 1 multiple_annotator_annotations \
	    multiple_annotators.csv
    ```

## Generate inter-annotator stats
The script `interannotator_stats.R` is used to generate Krippendorff's
alpha coefficient (to calculate inter-annotator reliability over the
entire video) and Fleiss' kappa (to calculate inter-annotator agreement
on a per-phase basis). It uses the annotation data extracted into
`multiple_annotator.csv`. It also requires the `phase_factors.csv`
generated in previous portions of the readme in order to translate
phase names and order then by user preference. Each second is treated
as a different "diagnosis" by an annotator and compared then between
annotators. An example invocation that calculates the statistics and
outputs Fleiss' kappa into fleiss.csv and Krippendorff's alpha into
kripp.csv is below:

```
interannotator_stats.R -f fleiss.csv -k kripp.csv phase_factors.csv \
    multiple_annotators.csv 
```

# Fingerprints
1. Run `pkl_dump.py` on pkl file to find out the class name, ground
   truth dict name, and model name
2. Run `make_model_results_tsv.py` to generate a directory full of TSVs
   that hold results per video
3. Run `Rscript fingerprints.R all` to generate a fingerprint per-video
	- eg `Rscript ../stats/for_git/fingerprints.R all -o /tmp/results -f video_stats/phase_factors.csv -t confusion/tsvs`
4. Run `Rscript fingerprints.R two` to generate a side-by-side
   fingerprint
   	- eg `Rscript ../stats/for_git/fingerprints.R two -H 7.5 -W 15 -o /tmp/results -f video_stats/phase_factors.csv -t confusion/tsvs video_08.tsv "Straightforward" video_10.tsv "Tortuous Esophagus"`

# Metrics and confusion matrix output
1. Run `pkl_dump.py` on pkl file to find out the class name, ground
   truth dict name, and model name
2. Run `make_model_results_tsv.py` to generate a directory full of TSVs
   that hold results per video
3. Run `Rscript model_metrics.R`
	- create `results_dir` first
	- for POEMpaper used width 12, height 8
	- for each video, and all vids combined, outputs:
		1. raw.tsv: all metrics data the R caret package calculates,
		   including overall accuracy (with CI) and per-phase recall,
		   precision, etc.
		2. perclass.tsv: table with precision, recall, f1, and
		   prevalence per-phase and averaged overall, both
		   prevalence and non-prevalence weighted (this is
		   identical to the table in the poemnet paper)
		3. confusion.tsv: table with tally for model's different
		   classifications for each gt phase
		4. recall and precision confusion matrix images

# Per duration stats
1. Run `pkl_dump.py` on pkl file to find out the class name, ground
   truth dict name, and model name
2. Run `make_model_results_tsv.py` to generate a directory full of TSVs
   that hold results per video
3. Run `per_block_duration_accuracy.R`
	- the example file `example_durations.csv` has durations for
	  poem paper

# Citation
If you found the code helpful for your research, please cite our paper:
```
@article{wardAutomatedOperativePhase2020,
  title = {Automated Operative Phase Identification in Peroral Endoscopic Myotomy},
  author = {Ward, Thomas M. and Hashimoto, Daniel A. and Ban, Yutong and Rattner, David W. and Inoue, Haruhiro and Lillemoe, Keith D. and Rus, Daniela L. and Rosman, Guy and Meireles, Ozanan R.},
  year = {2020},
  month = jul,
  issn = {1432-2218},
  doi = {10.1007/s00464-020-07833-9},
  journal = {Surgical Endoscopy},
  language = {en}
}
```
