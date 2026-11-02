# Only explicit Product offers in NOK are accepted; never guess from page text.
parse_price <- function(html) {
  tags <- regmatches(html, gregexpr('(?is)<script\\b[^>]*type=["\x27]application/ld\\+json["\x27][^>]*>.*?</script>', html, perl = TRUE))[[1]]
  find_products <- function(x) {
    if (!is.list(x)) return(list())
    if ('Product' %in% unlist(x[['@type']])) return(list(x))
    unlist(lapply(x, find_products), recursive = FALSE)
  }
  products <- list()
  for (tag in tags) {
    raw <- sub('(?is)</script>\\s*$', '', sub('(?is)^<script[^>]*>', '', tag, perl = TRUE), perl = TRUE)
    parsed <- tryCatch(jsonlite::fromJSON(raw, simplifyVector = FALSE), error = function(e) NULL)
    products <- c(products, find_products(parsed))
  }
  if (length(products) != 1L) stop('Expected exactly one structured Product')
  offer <- products[[1]]$offers
  if (is.null(offer$price)) stop('Missing single product offer')
  if (!identical(offer$priceCurrency, 'NOK')) stop('Currency is not NOK')
  price <- suppressWarnings(as.numeric(offer$price))
  if (length(price) != 1L || !is.finite(price) || price <= 0) stop('Invalid price')
  availability <- if (is.null(offer$availability)) 'Unknown' else sub('^.*/', '', offer$availability)
  list(price = price, availability = availability)
}

fetch_page <- function(url) {
  dest <- tempfile(fileext = '.html')
  on.exit(unlink(dest))
  old <- options(timeout = 30)
  on.exit(options(old), add = TRUE)
  status <- utils::download.file(url, dest, quiet = TRUE, mode = 'wb', method = 'libcurl',
    headers = c('User-Agent' = 'AIstart/0.1 (public grocery price research)'))
  if (status != 0) stop('Download failed')
  paste(readLines(dest, warn = FALSE, encoding = 'UTF-8'), collapse = '\n')
}

collect_prices <- function(products, fetch = fetch_page) {
  required <- c('store', 'product', 'litres', 'url')
  if (!all(required %in% names(products)) || !nrow(products)) stop('Invalid product configuration')
  if (anyNA(products[required]) || any(!is.finite(products$litres) | products$litres <= 0) ||
      any(!grepl('^https://', products$url))) stop('Invalid litres or source URL')
  rows <- lapply(seq_len(nrow(products)), function(i) {
    p <- products[i, required]
    message('Fetching ', p$store, ': ', p$product)
    result <- tryCatch(parse_price(fetch(p$url)), error = function(e) list(price = NA_real_, availability = 'Unknown', error = conditionMessage(e)))
    p$observed_at <- format(Sys.time(), '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
    p$price_nok <- result$price
    p$nok_per_litre <- round(result$price / p$litres, 2)
    p$availability <- result$availability
    p$status <- if (is.null(result$error)) 'ok' else result$error
    p
  })
  do.call(rbind, rows)
}
