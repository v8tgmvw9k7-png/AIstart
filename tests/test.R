source('R/prices.R')
source('R/report.R')
offer <- function(price = '20.5', currency = 'NOK') sprintf('<script type="application/ld+json">{"@graph":[{"@type":"Product","offers":{"price":"%s","priceCurrency":"%s","availability":"https://schema.org/InStock"}}]}</script>', price, currency)
fails <- function(expr) inherits(tryCatch(force(expr), error = identity), 'error')
stopifnot(parse_price(offer())$price == 20.5,
          fails(parse_price(offer(currency = 'EUR'))),
          fails(parse_price(offer(price = '-1'))),
          fails(parse_price('<html>20 kr</html>')),
          fails(parse_price(paste0(offer(), offer()))))
p <- data.frame(store = c('A', 'B'), product = c('<Milk>', 'Milk'), litres = c(1, 2), url = c('https://a.test', 'https://b.test'))
x <- collect_prices(p, function(url) if (url == p$url[1]) offer() else stop('offline'))
stopifnot(x$nok_per_litre[1] == 20.5, is.na(x$price_nok[2]), x$status[2] == 'offline')
y <- collect_prices(p, function(url) offer())
stopifnot(y$nok_per_litre[2] == 10.25)
f <- tempfile(fileext = '.html')
older <- y; older$observed_at <- '2026-01-01T00:00:00Z'
render_report(x, rbind(older, y), f, demo = TRUE)
s <- paste(readLines(f), collapse = '')
stopifnot(grepl('&lt;Milk&gt;', s, fixed = TRUE), grepl('offline', s), grepl('DEMO', s), grepl('data:image/png;base64,', s, fixed = TRUE))
render_report(x[2, , drop = FALSE], x[2, , drop = FALSE], f)
stopifnot(grepl('No available prices', paste(readLines(f), collapse = '')))
unlink(f)
cat('All tests passed.\n')
