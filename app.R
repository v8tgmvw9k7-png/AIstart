# Open this file in RStudio and click Run App.
if (dir.exists('.Rlibrary')) .libPaths(c(normalizePath('.Rlibrary'), .libPaths()))
for (package in c('shiny', 'jsonlite')) {
  if (!requireNamespace(package, quietly = TRUE)) {
    stop('Missing package ', package, '. Run install.packages(c("shiny", "jsonlite")) in the Console.')
  }
}
library(shiny)
source('R/prices.R', local = TRUE)
source('R/web.R', local = TRUE)
# Use an explicit shinyApp() call so RStudio recognizes this as a Shiny app.
components <- build_web_components()
ui <- components$ui
server <- components$server
shinyApp(ui = ui, server = server)
