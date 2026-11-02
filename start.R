# RStudio: source("start.R"), or open app.R and click Run App.
if (dir.exists('.Rlibrary')) .libPaths(c(normalizePath('.Rlibrary'), .libPaths()))
if (!requireNamespace('shiny', quietly = TRUE)) {
  stop('Install the web app dependencies first: install.packages(c("shiny", "jsonlite"))')
}
port <- suppressWarnings(as.integer(Sys.getenv('AISTART_PORT', '3838')))
if (is.na(port) || port < 1L || port > 65535L) stop('AISTART_PORT must be between 1 and 65535')
shiny::runApp('.', host = Sys.getenv('AISTART_HOST', '127.0.0.1'), port = port,
  launch.browser = !identical(Sys.getenv('AISTART_OPEN_REPORT'), 'false'))
