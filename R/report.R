escape_html <- function(x) {
  x <- gsub('&', '&amp;', as.character(x), fixed = TRUE)
  x <- gsub('<', '&lt;', x, fixed = TRUE)
  x <- gsub('>', '&gt;', x, fixed = TRUE)
  gsub('"', '&quot;', x, fixed = TRUE)
}
chart_svg <- function(draw) {
  path <- tempfile(fileext = '.png')
  grDevices::png(path, width = 1400, height = 672, res = 140, bg = '#ffffff')
  tryCatch(draw(), finally = grDevices::dev.off())
  out <- jsonlite::base64_enc(readBin(path, 'raw', n = file.info(path)$size))
  unlink(path)
  paste0('<img alt="Milk price chart" style="width:100%;height:auto" src="data:image/png;base64,', out, '">')
}
render_report <- function(current, history, output, demo = FALSE) {
  good <- current[current$status == 'ok' & current$availability == 'InStock', ]
  good <- good[order(good$nok_per_litre), ]
  comparison <- if (nrow(good)) chart_svg(function() {
    par(mar = c(5, 13, 2, 2))
    barplot(rev(good$nok_per_litre), names.arg = rev(paste(good$store, good$product)),
      horiz = TRUE, xlim = c(0, max(good$nok_per_litre) * 1.1), las = 1, col = '#187867', border = NA, xlab = 'NOK per litre', cex.names = .85)
  }) else '<p>No available prices were downloaded. See source errors below.</p>'
  valid <- history[history$status == 'ok' & history$availability == 'InStock', ]
  trend <- '<p>Run again on another day to start seeing price trends.</p>'
  if (nrow(valid) && length(unique(substr(valid$observed_at, 1, 10))) > 1) {
    trend <- chart_svg(function() {
      dates <- as.Date(substr(valid$observed_at, 1, 10))
      keys <- paste(valid$store, valid$product)
      groups <- unique(keys)
      colours <- grDevices::hcl.colors(length(groups), 'Dark 3')
      par(mar = c(5, 5, 2, 2))
      plot(range(dates), range(valid$nok_per_litre) + c(-.5, .5), type = 'n', xlab = 'Observation date (UTC)', ylab = 'NOK per litre')
      for (i in seq_along(groups)) {
        z <- which(keys == groups[i]); z <- z[order(valid$observed_at[z])]
        lines(dates[z], valid$nok_per_litre[z], type = 'o', col = colours[i], pch = 16)
      }
      legend('topleft', groups, col = colours, lty = 1, cex = .7, bty = 'n')
    })
  }
  rows <- vapply(seq_len(nrow(current)), function(i) {
    r <- current[i, ]
    values <- c(r$store, r$product, if (is.na(r$price_nok)) '—' else sprintf('%.2f', r$price_nok),
      if (is.na(r$nok_per_litre)) '—' else sprintf('%.2f', r$nok_per_litre), r$availability, r$status)
    paste0('<tr>', paste0('<td>', escape_html(values), '</td>', collapse = ''),
      '<td><a href="', escape_html(r$url), '">Product page</a></td></tr>')
  }, character(1))
  html <- paste0('<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">',
    '<title>AIstart · Milk price watch</title><style>body{margin:0;background:#f2f5f0;color:#182f2c;font:16px system-ui,sans-serif}main{max-width:1120px;margin:auto;padding:40px 24px}h1{font-size:clamp(32px,6vw,60px);letter-spacing:-2px;margin:12px 0}h2{font-size:24px}section{background:white;padding:24px;border-radius:16px;margin:24px 0}svg{width:100%;height:auto}table{border-collapse:collapse;width:100%;font-size:14px}td,th{text-align:left;padding:12px;border-bottom:1px solid #dde5df}.scroll{overflow:auto}a{color:#187867}.badge{color:#187867;font-weight:700;letter-spacing:2px}p{line-height:1.6}.notice{background:#fff0cd;padding:16px;border-radius:10px}</style><main>',
    '<div class="badge">AISTART / NORWAY</div><h1>Milk price watch.</h1><p>Public grocery prices, compared per litre.</p>',
    if (demo) '<p class="notice">DEMO — synthetic example prices, not current store prices.</p>' else '',
    '<p>Generated ', escape_html(format(Sys.time(), '%Y-%m-%d %H:%M UTC', tz = 'UTC')), ' · ', nrow(good), ' available offers from ', length(unique(good$store)), ' stores.</p>',
    '<section><h2>Price comparison</h2><p>Compare identical products across stores. Different milk types and pack sizes are separate products.</p>', comparison,
    '</section><section><h2>Price history</h2>', trend, '</section><section><h2>Sources and download status</h2><div class="scroll"><table><thead><tr>',
    paste0('<th>', c('Store', 'Product', 'NOK / pack', 'NOK / litre', 'Availability', 'Status', 'Source'), '</th>', collapse = ''),
    '</tr></thead><tbody>', paste(rows, collapse = ''), '</tbody></table></div></section>',
    '<p>Prices are observations of public product pages at download time, not checkout quotes. Location, delivery date, membership and promotions may change the price. Delivery fees are excluded. Failed downloads are shown explicitly; old prices are never substituted for current observations. Only in-stock offers appear in charts.</p></main></html>')
  dir.create(dirname(output), recursive = TRUE, showWarnings = FALSE)
  writeLines(html, output, useBytes = TRUE)
  invisible(output)
}
