#!/usr/bin/env Rscript
# Run from the project root: Rscript run.R [--demo]
if (!requireNamespace('jsonlite', quietly = TRUE)) stop('Install jsonlite first: install.packages("jsonlite")')
source('R/prices.R')
source('R/report.R')
args <- if (interactive()) character() else commandArgs(trailingOnly = TRUE)
if (any(!args %in% '--demo')) stop('Usage: Rscript run.R [--demo]')
demo <- '--demo' %in% args
products <- read.csv('config/products.csv', stringsAsFactors = FALSE)
if (demo) {
  current <- collect_prices(products, local({
    i <- 0L
    function(url) {
      i <<- i + 1L
      sprintf('<script type="application/ld+json">{"@type":"Product","offers":{"price":%s,"priceCurrency":"NOK","availability":"https://schema.org/InStock"}}</script>', c(20, 23, 21, 24)[(i - 1L) %% 4L + 1L])
    }
  }))
  history <- current
  output <- 'reports/demo.html'
} else {
  current <- collect_prices(products)
  dir.create('data', showWarnings = FALSE)
  history_file <- 'data/history.csv'
  history <- if (file.exists(history_file)) rbind(read.csv(history_file, stringsAsFactors = FALSE), current) else current
  write.csv(history, history_file, row.names = FALSE, na = '')
  write.csv(current, 'data/latest.csv', row.names = FALSE, na = '')
  output <- 'reports/index.html'
}
render_report(current, history, output, demo)
message('Report written to ', normalizePath(output))
if (!demo && all(current$status != 'ok')) {
  if (interactive()) stop('No prices downloaded. See reports/index.html for details.')
  quit(status = 1L)
}
