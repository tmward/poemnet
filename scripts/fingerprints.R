#!/usr/bin/env Rscript
"Takes a directory of TSVs generated by make_model_results_tsv.py and will generate surgical fingerprints.
If the 'all' function is used, it will generate a fingerprint per video. If the 'two' function is used,
it will generate a side-by-side fingerprint.

Usage:
	fingerprints.R [-h] all [-W WIDTH] [-H HEIGHT] [-E IMGEXT] -o OUTDIR -f FACTORS -t TSVDIR
	fingerprints.R [-h] two [-W WIDTH] [-H HEIGHT] [-E IMGEXT] -o OUTDIR -f FACTORS -t TSVDIR VID1 TITLE1 VID2 TITLE2

Options:
	-h             Print this menu and exit.
	-f FACTORS     CSV file that holds short to long name map and ordered in user preferences that save files will keep (eg temporally).
	-o OUTDIR      Directory (already created) in which to place the results.
	-W WIDTH       Width of output plots in cm [default: 15].
	-H WIDTH       Width of output plots in cm [default: 10].
	-E IMGEXT      File-format for image extension [default: png].
	-t TSVDIR      Directory full of TSVs on model results per video.

Arguments:
	VID1           Filename of first fingerprint video's TSV in TSVDIR.
	TITLE1         Title to give first fingerprint in plot.
	VID2           Filename of second fingerprint video's TSV in TSVDIR.
	TITLE2         Title to give second fingerprint in plot.
" -> doc

library(docopt)
suppressPackageStartupMessages(library(tidyverse))

get_levels <- function(factor_file) {
  # Factor info has the correct order of the phases already (user entered
  # them in the csv file in the correct order. Add a level "Idle" which will
  # replace NA in the non-annotated seconds
  read_csv(factor_file, col_types = "cc") %>%
    .[["name"]]
}

make_phase_translation <- function(factor_file) {
  # csv structure nicely allows us to create a map (named vector in R) with deframe()
  # fct_recode will later want this in full_name, name order so flip the columns around
  # with select
  read_csv(factor_file, col_types = "cc") %>%
    select(full_name, name) %>%
    deframe()
}


get_video_results <- function(tsv_files, factor_file) {
  tsv_files %>%
    map(read_tsv, col_types = cols(
      second = col_integer(),
      vid_num = col_integer(),
      block = col_integer(),
      gt = col_character(),
      predicted = col_character(),
      .default = col_double()
    )) %>%
    map(tidy_results, factor_file)
}

# takes a tidied dataframe for a video and plots the fingerprint
# Fingerprint contains the probability for each time second,
# plotted with geom_tile, and also plots the ground_truth as a "line"
# (plotted with geom_point shaped like squares)
# I checked colors on color-blind website and looked fine no matter color-blindness
plot_fingerprint <- function(df) {
  df %>%
    # flip around order so that on y-axis "first" step will appear at the top
    mutate(gt = fct_rev(gt), prediction = fct_rev(prediction)) %>%
    ggplot(mapping = aes(x = second, y = prediction, fill = probability)) +
    geom_tile() +
    scale_fill_gradient(name = "Probability\n", low = "white", high = "#000099", limits = c(0, 1)) +
    labs(
      x = "Time (s)",
      y = "Identified Phase"
    ) +
    theme_classic() +
    theme(
      axis.ticks.y = element_blank()
    ) +
    # draw the ground truth as red "lines" (really a bunch of points, shape=15 is a square instead of
    # standard circle point so the edges are squared)
    geom_point(mapping = aes(x = second, y = gt, color = "Ground Truth"), shape = 15, size = 2) +
    scale_color_manual(name = "", labels = "Ground Truth", values = c("Ground Truth" = "red"))
}

save_fingerprint <- function(finger_plot, save_file, save_path, plot_width, plot_height) {
  ggsave(save_file, plot = finger_plot, width = plot_width, height = plot_height, units = c("cm"), path = save_path)
}


tidy_results <- function(df, factor_file) {
  phase_levels <- get_levels(factor_file)
  phase_translation <- make_phase_translation(factor_file)

  df %>%
    # don't need these columns
    select(-block, -predicted) %>%
    # pivot longer to make a row for the likelihood of each step per second, select all the
    # columns except the first three (which are second, vid_num, gt), thereby getting all the
    # columns that are phases as the header and their probability per second
    pivot_longer(cols = -(1:3), names_to = "prediction", values_to = "probability") %>%
    # make names factors so they are ordered correctly
    mutate_at(vars(gt, prediction), parse_factor, levels = phase_levels) %>%
    # make names long-form ('!!!' unpacks named vector of full_name:name)
    mutate_at(vars(gt, prediction), fct_recode, !!!phase_translation)
}

list_tsvs <- function(tsv_dir) {
  # all videos in format video_NN.tsv with header:
  # (second, vid_num, block, gt, predicted, step_01, ..., step_NN)
  dir(path = tsv_dir, pattern = "^video_\\d{2}.tsv$", full.names = TRUE)
}

# return character vector joining tsv_dir to its arguments
make_tsv_list <- function(tsv_dir, ...) {
  map_chr(c(...), ~ file.path(tsv_dir, .))
}

# outputs a plot that combined two video fingerprints side-by-side
# facet_wrap means you don't duplicate the legend, the y-axis on the second
# video doesn't get superflously plotted, and the x-axis is centered nicely
# between the two plots. Scaling is also quite nice.
plot_combined_fingerprint <- function(df_1, title_1, df_2, title_2) {
  # use factors to ensure plots are ordered in specified order rather
  # than the default lexagraphical order
  title_levels <- c(title_1, title_2)

  # give each table a column that holds their title, then bind together
  bind_rows(mutate(df_1, vid_title = title_1), mutate(df_2, vid_title = title_2)) %>%
    mutate(vid_title = parse_factor(vid_title, levels = title_levels)) %>%
    plot_fingerprint() +
    facet_wrap(vars(vid_title), ncol = 2)
}

# takes an extension, then any number of filenames to generate a save name for combined fingerprints
make_combined_filename <- function(plot_ext, ...) {
  str_remove(c(...), ".(tsv|TSV)$") %>%
    # to the character vector of names, add "fingerprint.plotext"
    c(., str_c("fingerprint.", plot_ext)) %>%
    # join all the components of the character vector with an underscore
    str_c(collapse = "_")
}


main <- function(opts) {
  if (opts$all) {
    list_tsvs(opts$t) %>%
      get_video_results(opts$f) %>%
      map(plot_fingerprint) %>%
      walk2(
        seq_along(.),
        # filename to pass is video_NN_fingerprint.IMGEXT
        # generate NN with seq_along and str_pad
        # width and height are strings so convert to numeric as well
        ~ save_fingerprint(
          .x, str_c("video_", str_pad(.y, 2, side = c("left"), pad = "0"), "_fingerprint.", opts$E),
          opts$o, as.numeric(opts$W), as.numeric(opts$H)
        )
      )
  } else if (opts$two) {
    combo_results <- make_tsv_list(opts$t, opts$VID1, opts$VID2) %>%
      get_video_results(opts$f) # %>% (for some reason can't get this to work in a pipe so save as a variable)

    # TODO long-term: be able to specify unlimited number of videos (I already did the work in
    # make_tsv_list() and make_combined_filename() to allow for this, plot_combined_fingerprint() is the
    # only function that will need to be modified to work (in addition to the CLI input)
    plot_combined_fingerprint(
      combo_results[[1]], opts$TITLE1,
      combo_results[[2]], opts$TITLE2
    ) %>%
      save_fingerprint(
        make_combined_filename(opts$E, opts$VID1, opts$VID2),
        opts$o, as.numeric(opts$W), as.numeric(opts$H)
      )
  }
}

opt <- docopt(doc)
main(opt)
