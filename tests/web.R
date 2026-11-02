.libPaths(c(normalizePath('.Rlibrary', mustWork = FALSE), .libPaths()))
source('R/prices.R')
source('R/web.R')
catalogue <- read_catalogue()
path <- tempfile(fileext = '.rds')
fetches <- character()
fake <- function(url) {
  fetches <<- c(fetches, url)
  if (grepl('meny.no', url)) stop('Test download failure')
  '<script type="application/ld+json">{"@type":"Product","offers":{"price":"33","priceCurrency":"NOK","availability":"https://schema.org/InStock"}}</script>'
}
app <- make_web_app(catalogue, path, fake)
shiny::testServer(app$serverFuncSource(), {
  session$setInputs(category = 'Eggs', product = 'eggs-prior-6', stores = 'Oda')
  stopifnot(nrow(selected()) == 1, nrow(observations()) == 0)
  session$setInputs(refresh = 1)
  stopifnot(length(fetches) == 1, nrow(observations()) == 1,
    available()$nok_per_unit == 5.5, file.exists(path))
  session$setInputs(category = 'Milk', product = 'milk-1', stores = c('Oda', 'MENY'))
  stopifnot(nrow(observations()) == 0)
  session$setInputs(refresh = 2)
  stopifnot(length(fetches) == 3, nrow(observations()) == 2, nrow(available()) == 1,
    observations()$status[2] == 'Test download failure', nrow(readRDS(path)) == 3)
  session$setInputs(stores = character())
  session$setInputs(refresh = 3)
  stopifnot(length(fetches) == 3, nrow(observations()) == 0)
  session$setInputs(category = 'Oats', product = 'oats-axa', stores = 'Oda')
  session$setInputs(refresh = 4)
  stopifnot(available()$nok_per_unit == 30, nrow(readRDS(path)) == 4)
})
stopifnot(nrow(readRDS(path)) == 4)
# Restart the app: stored observations survive.
app <- make_web_app(catalogue, path, fake)
shiny::testServer(app$serverFuncSource(), {
  session$setInputs(category = 'Eggs', product = 'eggs-prior-6', stores = 'Oda')
  stopifnot(nrow(observations()) == 1, available()$nok_per_unit == 5.5)
})
unlink(path)
cat('Web app tests passed.\n')

# Exercise the real app.R entry point, including its HTTP UI handler.
entry <- source('app.R', local = new.env())$value
request <- list(REQUEST_METHOD = 'GET', PATH_INFO = '/', QUERY_STRING = '',
                SCRIPT_NAME = '', HTTP_ACCEPT = 'text/html')
response <- entry$httpHandler(request)
stopifnot(response$status == 200L,
          grepl('Grocery price watch.', paste(response$content, collapse = ''), fixed = TRUE),
          !grepl('No UI defined', paste(response$content, collapse = ''), fixed = TRUE))
cat('App entry point serves the grocery UI.\n')
