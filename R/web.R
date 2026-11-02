read_catalogue <- function(path = 'config/web_products.csv') {
  x <- read.csv(path, stringsAsFactors = FALSE)
  required <- c('product_id', 'category', 'store', 'product', 'quantity', 'unit', 'url')
  if (!all(required %in% names(x)) || !nrow(x) || anyNA(x[required])) stop('Invalid product catalogue')
  if (any(!is.finite(x$quantity) | x$quantity <= 0) || any(!x$unit %in% c('L', 'kg', 'item')) ||
      any(!grepl('^https://', x$url)) || anyDuplicated(x$url)) stop('Invalid quantities, units or URLs')
  for (id in unique(x$product_id)) {
    rows <- x[x$product_id == id, ]
    if (length(unique(rows$unit)) != 1L || length(unique(rows$product)) != 1L ||
        length(unique(rows$category)) != 1L) stop('Product IDs must identify one product and unit')
  }
  x
}

collect_catalogue <- function(products, fetch = fetch_page) {
  legacy <- products[c('store', 'product', 'url')]
  legacy$litres <- products$quantity
  results <- collect_prices(legacy, fetch)
  cbind(products, results[c('observed_at', 'price_nok', 'availability', 'status')],
        nok_per_unit = round(results$price_nok / products$quantity, 2))
}

empty_history <- function(catalogue) {
  x <- catalogue[FALSE, ]
  x$observed_at <- character(); x$price_nok <- numeric()
  x$availability <- character(); x$status <- character(); x$nok_per_unit <- numeric()
  x
}

save_web_history <- function(x, path) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  tmp <- tempfile(tmpdir = dirname(path))
  on.exit(unlink(tmp))
  saveRDS(x, tmp)
  if (!file.rename(tmp, path)) stop('Could not save price history')
}

latest_offers <- function(history, products) {
  if (!nrow(history)) return(history)
  x <- history[history$url %in% products$url, ]
  x[!duplicated(x$url, fromLast = TRUE), , drop = FALSE]
}

build_web_components <- function(catalogue = read_catalogue(), history_path = 'data/web-history.rds', fetch = fetch_page) {
  initial <- if (file.exists(history_path)) readRDS(history_path) else empty_history(catalogue)
  history <- shiny::reactiveVal(initial)
  ui <- shiny::fluidPage(
    shiny::tags$head(shiny::tags$style(shiny::HTML('
      body {background:#f2f5f0;color:#18332e;font-family:system-ui,sans-serif}
      .container-fluid{max-width:1280px;padding:32px 24px}h1{font-size:44px;font-weight:750;letter-spacing:-1.5px}
      .well{background:white;border:0;border-radius:16px;box-shadow:none;padding:24px}
      .panel-card{background:white;border-radius:16px;padding:24px;margin-bottom:24px}
      .btn-primary{background:#187867;border-color:#187867}.eyebrow{color:#187867;letter-spacing:2px;font-weight:700}
      .shiny-output-error-validation{color:#52645d}.table{font-size:14px}a{color:#187867}
      .help-block{line-height:1.6} .table-wrap{overflow-x:auto}
    '))),
    shiny::div(class = 'eyebrow', 'AISTART / NORWAY'),
    shiny::h1('Grocery price watch.'),
    shiny::p('Choose a product. Check prices. Follow changes over time.'),
    shiny::sidebarLayout(
      shiny::sidebarPanel(
        shiny::selectInput('category', 'Category', unique(catalogue$category)),
        shiny::uiOutput('product_picker'),
        shiny::uiOutput('store_picker'),
        shiny::actionButton('refresh', 'Refresh selected prices', class = 'btn-primary'),
        shiny::hr(),
        shiny::helpText('Only the selected product pages are downloaded when you refresh. Saved observations remain visible with their timestamps.'),
        shiny::downloadButton('download', 'Download observations (CSV)'),
        shiny::hr(),
        shiny::helpText('Prices may vary by location, delivery date, membership and promotions. Delivery fees are excluded.')
      ),
      shiny::mainPanel(
        shiny::div(class = 'panel-card', shiny::h3('Available offers'), shiny::textOutput('summary'),
          shiny::plotOutput('comparison', height = '300px')),
        shiny::div(class = 'panel-card', shiny::h3('Latest observations'),
          shiny::div(class = 'table-wrap', shiny::tableOutput('prices')), shiny::uiOutput('sources')),
        shiny::div(class = 'panel-card', shiny::h3('Price history'), shiny::plotOutput('trend', height = '300px'))
      )
    )
  )
  server <- function(input, output, session) {
    category_products <- shiny::reactive({
      shiny::req(input$category)
      catalogue[catalogue$category == input$category, ]
    })
    output$product_picker <- shiny::renderUI({
      x <- category_products(); x <- x[!duplicated(x$product_id), ]
      shiny::selectInput('product', 'Product', stats::setNames(x$product_id, x$product))
    })
    product_rows <- shiny::reactive({
      shiny::req(input$product)
      x <- category_products()
      x[x$product_id == input$product, , drop = FALSE]
    })
    output$store_picker <- shiny::renderUI({
      x <- product_rows()
      shiny::checkboxGroupInput('stores', 'Stores', unique(x$store), selected = unique(x$store))
    })
    selected <- shiny::reactive({
      x <- product_rows()
      x[x$store %in% input$stores, , drop = FALSE]
    })
    observations <- shiny::reactive({
      latest_offers(history(), selected())
    })
    available <- shiny::reactive({
      x <- observations()
      x[x$status == 'ok' & x$availability == 'InStock' & is.finite(x$nok_per_unit), , drop = FALSE]
    })
    shiny::observeEvent(input$refresh, {
      x <- selected()
      if (!nrow(x)) {
        shiny::showNotification('Select at least one store.', type = 'warning'); return()
      }
      shiny::withProgress(message = 'Downloading selected prices', value = 0, {
        tryCatch({
          rows <- collect_catalogue(x, fetch)
          updated <- rbind(shiny::isolate(history()), rows)
          save_web_history(updated, history_path)
          history(updated)
          failures <- sum(rows$status != 'ok')
          shiny::showNotification(if (failures) paste(failures, 'download(s) failed. See the status table.') else 'Prices refreshed.',
                                  type = if (failures) 'warning' else 'message')
        }, error = function(e) shiny::showNotification(conditionMessage(e), type = 'error', duration = NULL))
      })
    })
    output$summary <- shiny::renderText({
      x <- observations()
      if (!nrow(selected())) return('Choose a product and at least one store.')
      if (!nrow(x)) return('No saved observations for this selection. Click Refresh selected prices.')
      paste(nrow(available()), 'in-stock offer(s). Unit: NOK /', selected()$unit[1],
            '· Last observation:', max(x$observed_at),
            if (nrow(selected()) > nrow(x)) '· Some stores have no saved observation yet.' else '')
    })
    output$comparison <- shiny::renderPlot({
      x <- available()
      shiny::validate(shiny::need(nrow(x) > 0, 'Refresh prices to see available offers.'))
      x <- x[order(x$nok_per_unit, decreasing = TRUE), ]
      par(mar = c(5, 7, 1, 2))
      barplot(x$nok_per_unit, names.arg = x$store, horiz = TRUE, las = 1,
        xlim = c(0, max(x$nok_per_unit) * 1.15), col = '#187867', border = NA,
        xlab = paste('NOK /', x$unit[1]))
    })
    output$prices <- shiny::renderTable({
      x <- observations()
      shiny::validate(shiny::need(nrow(x) > 0, 'No observations yet.'))
      data.frame(Store = x$store, Product = x$product, `Pack price (NOK)` = x$price_nok,
        `Unit price (NOK)` = x$nok_per_unit, Unit = x$unit, Availability = x$availability,
        `Observed (UTC)` = x$observed_at, Status = x$status, check.names = FALSE)
    }, striped = TRUE, bordered = FALSE, na = '—', digits = 2)
    output$sources <- shiny::renderUI({
      x <- selected()
      shiny::tagList(shiny::p('Product sources:'), shiny::tags$ul(lapply(seq_len(nrow(x)), function(i)
        shiny::tags$li(shiny::tags$a(href = x$url[i], target = '_blank', rel = 'noopener', paste(x$store[i], x$product[i]))))))
    })
    output$trend <- shiny::renderPlot({
      x <- history(); x <- x[x$url %in% selected()$url & x$status == 'ok' & x$availability == 'InStock', ]
      shiny::validate(shiny::need(nrow(x) > 1 && length(unique(x$observed_at)) > 1,
        'Refresh again later to see price history.'))
      dates <- as.POSIXct(x$observed_at, format = '%Y-%m-%dT%H:%M:%SZ', tz = 'UTC')
      par(mar = c(5, 5, 1, 2))
      plot(range(dates), range(x$nok_per_unit) + c(-.5, .5), type = 'n',
        xlab = 'Observation time (UTC)', ylab = paste('NOK /', x$unit[1]))
      stores <- unique(x$store); colours <- grDevices::hcl.colors(length(stores), 'Dark 3')
      for (i in seq_along(stores)) {
        z <- which(x$store == stores[i]); z <- z[order(dates[z])]
        lines(dates[z], x$nok_per_unit[z], type = 'o', pch = 16, col = colours[i])
      }
      legend('topleft', stores, col = colours, lty = 1, pch = 16, bty = 'n')
    })
    output$download <- shiny::downloadHandler(
      filename = function() paste0('aistart-', Sys.Date(), '.csv'),
      content = function(file) {
        x <- history(); x <- x[x$url %in% selected()$url, , drop = FALSE]
        utils::write.csv(x, file, row.names = FALSE, na = '')
      }
    )
  }
  list(ui = ui, server = server)
}

make_web_app <- function(catalogue = read_catalogue(), history_path = 'data/web-history.rds', fetch = fetch_page) {
  components <- build_web_components(catalogue, history_path, fetch)
  shiny::shinyApp(ui = components$ui, server = components$server)
}
