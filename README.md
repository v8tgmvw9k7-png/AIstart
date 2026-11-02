# AIstart

An R/Shiny web app for checking Norwegian grocery prices. Choose a category,
product and stores, refresh public prices, compare unit prices, and follow
recorded changes over time. The starter catalogue includes milk, eggs and oats.

## Start in RStudio

1. Open `AIstart.Rproj`.
2. Choose **Build > Build All** from the top menu, or press **Cmd+Shift+B**
   on macOS. No Console command is needed.
   Alternatively, open `app.R` in the editor and click **Run App**, or press
   **Cmd+Shift+Enter** with that file active. If it was already open before the
   update, close its editor tab and reopen it from the Files pane.
3. Choose a category, product and stores, then click **Refresh selected prices**.

`start.R` opens the app at http://127.0.0.1:3838. Keep R running while using it.
Use RStudio's **Stop** button or Escape in the Console to stop the server.
If port 3838 is in use, stop the previous server or run
`Sys.setenv(AISTART_PORT = "3839")` before starting.

Requires R 4.1+ and `shiny` and `jsonlite`. Dependencies have been installed
locally in `.Rlibrary` on this computer. On a new computer, install once:

```r
install.packages(c("shiny", "jsonlite"))
```

From a terminal:

```sh
Rscript start.R
```

## Using the app

- The category and product menus select one specific product at a time, so
  milk is never ranked against eggs or oats.
- Store checkboxes control which offers are displayed and refreshed. The
  initial catalogue has Oda and MENY milk offers; eggs and oats currently have
  Oda offers only. More stores can be added to the catalogue.
- Prices are normalized to NOK per litre, kilogram or item. Pack prices and
  observation times are also shown.
- Downloads happen only when you click refresh. Saved observations load on
  startup; timestamps tell you when each price was fetched. Missing offers and
  errors are shown explicitly, and failed downloads replace the previous
  offer in the latest table. Only successful in-stock offers appear in charts.
- History is saved in `data/web-history.rds`. The CSV button exports all saved
  observations for the current product and selected stores.
- History charts appear after multiple distinct observation times; no past
  prices are invented. Existing static milk reports and CSV history remain
  separate from the new app's observations.

## Add products

Edit `config/web_products.csv`, then restart the app. Each row contains:

| Column | Meaning |
| --- | --- |
| product_id | Stable ID shared by offers of the same exact product |
| category | Category menu label |
| store | Store name |
| product | Full product label including pack size |
| quantity | Pack quantity in the stated unit, e.g. 1.1 kg or 6 eggs |
| unit | `L`, `kg`, or `item` |
| url | Public HTTPS product page |

Verify the exact product, variant and pack size manually. Only share a
product ID between equivalent offers. Product labels, categories and units
must agree for each ID. The collector supports pages exposing one Schema.org
Product with a single explicit NOK offer; it does not search every store or
read prices rendered only by JavaScript. Incompatible pages show a download
error rather than an estimated price.

## Server use

The default server listens only on this computer. To run it on a trusted local
network, start with `AISTART_HOST=0.0.0.0 Rscript start.R` and open the computer's
LAN address on port 3838 from another device. This app has no accounts or
access control; public hosting needs a suitable Shiny hosting service or a
reverse proxy with HTTPS and authentication. Run one R process per history
file: observations are shared across browser sessions in that process, and
history writes use atomic file replacement. Multiple independent server
processes need a database instead of this file store.

Optional environment variables: `AISTART_PORT` (default `3838`),
`AISTART_HOST` (default `127.0.0.1`), and `AISTART_OPEN_REPORT=false` to suppress
opening a browser from `start.R`.

## Existing static report and tests

The original milk report is still available:

```sh
Rscript run.R
Rscript run.R --demo
make test
```

Live HTML output is in `reports/index.html`; the synthetic offline example is
in `reports/demo.html`. Static milk history is in `data/history.csv`.
`make test` runs offline parser/report checks and Shiny server tests for
selection, unit conversion, partial failures and persisted history.

## Price sources and limits

Prices are downloaded directly from public product pages at
[Oda](https://oda.com/no/products/430-tine-tine-lettmelk-1-fett/) and
[MENY](https://meny.no/varer/meieri-egg/melk/lettmelk/lettmelk-1-0-7038010001642).
Location, delivery date, membership, availability, promotions and checkout
pricing may differ. Delivery fees are excluded. Each selected page has a
30-second download timeout; refreshes run sequentially. Check store access
terms before increasing collection frequency. Website changes may break a
source; failures stay visible in the app.
