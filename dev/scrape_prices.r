# dev/scrape_prices.r
# -----------------------------------------------------------------------------
# Scrape current product prices from South African sports-nutrition retailers
# for the "Rands per gram for sports" blog post.
#
# Reads:  blog/data/product_urls.csv  (Product, Brand, URL, Serving_Size,
#                                       Carbs_per_Serving)
# Writes: blog/data/products.csv       (above + Price_ZAR, scraped_at, status)
#
# Usage (from project root):
#   Rscript dev/scrape_prices.r              # scrape all rows
#   Rscript dev/scrape_prices.r --brand SiS  # filter by brand substring
#   Rscript dev/scrape_prices.r --dry-run    # parse 3 rows, do not write
#
# Supports per-domain CSS selectors plus a JSON-LD fallback that works for
# most Shopify / WooCommerce / Magento stores. Polite: 1.5 s delay between
# requests, realistic user-agent, retries on transient failures.
# -----------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(rvest)
  library(httr2)
  library(dplyr)
  library(stringr)
  library(readr)
  library(purrr)
  library(jsonlite)
})

# ---- config -----------------------------------------------------------------
PROJECT_ROOT <- tryCatch({
  this_file <- normalizePath(sub("^--file=", "", grep("^--file=", commandArgs(trailingOnly = FALSE), value = TRUE)[1]), mustWork = FALSE)
  if (is.na(this_file) || !nzchar(this_file)) stop("no file")
  normalizePath(file.path(dirname(this_file), ".."), mustWork = FALSE)
}, error = function(e) getwd())
URLS_PATH     <- file.path(PROJECT_ROOT, "blog/data/product_urls.csv")
OUT_PATH      <- file.path(PROJECT_ROOT, "blog/data/products.csv")
USER_AGENT    <- "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36 StudyStats-PriceBot/1.0 (+https://study-stats.com)"
REQUEST_DELAY <- 1.5   # seconds between requests
TIMEOUT_SEC   <- 20

# ---- helpers ----------------------------------------------------------------
`%||%` <- function(a, b) if (is.null(a) || length(a) == 0 || (is.character(a) && !nzchar(a))) b else a

clean_price <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  x <- as.character(x)[1]
  # extract first price-like token: optional R, digits with , or . separators
  m <- str_match(x, "[Rr]?\\s*([0-9]{1,3}(?:[,\\s][0-9]{3})*(?:[.,][0-9]{1,2})?|[0-9]+(?:[.,][0-9]{1,2})?)")
  if (is.na(m[1, 2])) return(NA_real_)
  v <- m[1, 2]
  # remove thousand separators (space or comma followed by exactly 3 digits)
  v <- str_replace_all(v, "[\\s,](?=[0-9]{3}(?:[^0-9]|$))", "")
  # remaining comma = decimal
  v <- str_replace(v, ",", ".")
  suppressWarnings(as.numeric(v))
}

fetch_html <- function(url) {
  req <- request(url) |>
    req_user_agent(USER_AGENT) |>
    req_headers(`Accept-Language` = "en-ZA,en;q=0.9") |>
    req_timeout(TIMEOUT_SEC) |>
    req_retry(max_tries = 3, backoff = ~ 2)
  resp <- tryCatch(req_perform(req), error = function(e) e)
  if (inherits(resp, "error")) return(list(html = NULL, error = conditionMessage(resp)))
  if (resp_status(resp) >= 400) return(list(html = NULL, error = paste0("HTTP ", resp_status(resp))))
  list(html = read_html(resp_body_string(resp)), error = NA_character_)
}

# JSON-LD generic extractor (covers Shopify, Woo, Magento, many custom stacks)
price_from_jsonld <- function(html) {
  if (is.null(html)) return(NA_real_)
  blocks <- html |> html_elements("script[type='application/ld+json']") |> html_text()
  for (b in blocks) {
    parsed <- tryCatch(fromJSON(b, simplifyVector = FALSE), error = function(e) NULL)
    if (is.null(parsed)) next
    # parsed may be a list of objects or a single object; flatten
    candidates <- list(parsed)
    if (is.null(parsed$`@type`) && length(parsed) > 0) candidates <- parsed
    for (obj in candidates) {
      ty <- obj$`@type` %||% ""
      if (any(c("Product", "product") %in% ty) || !is.null(obj$offers)) {
        offers <- obj$offers
        # offers can be list, AggregateOffer, or array
        flat <- list(offers)
        if (!is.null(offers$offers)) flat <- list(offers, offers$offers)
        for (o in flat) {
          if (is.null(o)) next
          p <- o$price %||% o$lowPrice %||% o$highPrice
          if (!is.null(p)) {
            v <- clean_price(p)
            if (!is.na(v) && v > 0) return(v)
          }
        }
      }
    }
  }
  NA_real_
}

# per-domain CSS selectors (return first matching numeric)
domain_selectors <- list(
  "takealot.com"          = c("[data-ref='buybox-actual-price']", ".buybox-module_currency-value_29XEd", "[itemprop='price']"),
  "dischem.co.za"         = c(".product-price__price", ".price"),
  "dischemlivingfit.co.za"= c(".price ins .amount", ".price .amount", ".woocommerce-Price-amount"),
  "cyclelab.com"          = c(".product-price", ".price", "[itemprop='price']"),
  "scienceinsport.co.za"  = c(".price-item--regular", ".price__regular .price-item", ".product__price"),
  "biogen.co.za"          = c(".woocommerce-Price-amount", ".price"),
  "cadencenutrition.com"  = c(".price-item--regular", ".product-price"),
  "226ers.co.za"          = c(".price-item--regular", ".product-price"),
  "pvm.co.za"             = c(".woocommerce-Price-amount", ".price"),
  "32gi.co.za"            = c(".price-item--regular", ".product-price"),
  "thesweatshop.co.za"    = c(".price-item--regular", ".product-price"),
  "vivovitasport.com"     = c(".woocommerce-Price-amount", ".price"),
  "gearchange.co.za"      = c(".price-item--regular", ".product-price"),
  "durbanrunner.co.za"    = c(".price-item--regular", ".product-price"),
  "sisunutrition.co.za"   = c(".woocommerce-Price-amount", ".price"),
  "carbonendurance.co"    = c(".product-price", ".price-item--regular"),
  "archcycles.co.za"      = c(".price-item--regular", ".product-price"),
  "solomonscycles.co.za"  = c(".woocommerce-Price-amount", ".price"),
  "finishlinecycles.co.za"= c(".price-item--regular", ".product-price"),
  "xciter.co.za"          = c(".price-item--regular", ".product-price"),
  "specializedpaarl.com"  = c(".price-item--regular", ".product-price"),
  "kragkroeg.co.za"       = c(".woocommerce-Price-amount", ".price"),
  "pnp.co.za"             = c("[data-cnstrc-item-price]", ".product-price"),
  "sportsmanswarehouse.co.za" = c(".product-price", "[data-testid='product-price']"),
  "loot.co.za"            = c(".product-price", ".price"),
  "maurten.co.za"         = c(".price-item--regular", ".product-price"),
  "za.usn.global"         = c(".price-item--regular", ".price__regular .price-item")
)

price_from_selectors <- function(html, host) {
  if (is.null(html)) return(NA_real_)
  sels <- domain_selectors[[host]]
  if (is.null(sels)) return(NA_real_)
  for (s in sels) {
    txt <- html |> html_elements(s) |> html_text(trim = TRUE)
    txt <- txt[nzchar(txt)]
    for (t in txt) {
      v <- clean_price(t)
      if (!is.na(v) && v > 0) return(v)
    }
  }
  NA_real_
}

extract_price <- function(url) {
  host_full <- tolower(httr2::url_parse(url)$hostname %||% "")
  host_full <- sub("^www\\.", "", host_full)
  page <- fetch_html(url)
  if (!is.null(page$error) && !is.na(page$error)) return(list(price = NA_real_, status = page$error))
  p <- price_from_selectors(page$html, host_full)
  if (is.na(p)) p <- price_from_jsonld(page$html)
  if (is.na(p)) return(list(price = NA_real_, status = "no-price-found"))
  list(price = p, status = "ok")
}

# ---- main -------------------------------------------------------------------
args     <- commandArgs(trailingOnly = TRUE)
dry_run  <- "--dry-run" %in% args
brand_f  <- {
  i <- match("--brand", args); if (!is.na(i)) args[i + 1] else NULL
}

if (!file.exists(URLS_PATH)) {
  stop("Missing input: ", URLS_PATH,
       "\nCreate it (Product, Brand, URL, Serving_Size, Carbs_per_Serving) first.")
}

urls_df <- read_csv(URLS_PATH, show_col_types = FALSE)
required <- c("Product", "Brand", "URL", "Serving_Size", "Carbs_per_Serving")
miss <- setdiff(required, names(urls_df))
if (length(miss)) stop("Missing columns in product_urls.csv: ", paste(miss, collapse = ", "))
if (!"Pack_Size" %in% names(urls_df)) urls_df$Pack_Size <- 1   # divide scraped price by this

if (!is.null(brand_f)) urls_df <- urls_df |> filter(str_detect(tolower(Brand), tolower(brand_f)))
if (dry_run) urls_df <- head(urls_df, 3)

message(sprintf("Scraping %d product(s)...", nrow(urls_df)))

results <- vector("list", nrow(urls_df))
for (i in seq_len(nrow(urls_df))) {
  row <- urls_df[i, ]
  res <- extract_price(row$URL)
  pack <- as.numeric(row$Pack_Size %||% 1); if (is.na(pack) || pack <= 0) pack <- 1
  price_unit <- if (is.na(res$price)) NA_real_ else res$price / pack
  results[[i]] <- tibble(
    Product = row$Product,
    Brand = row$Brand,
    Price_ZAR = price_unit,
    Pack_Size = pack,
    Serving_Size = row$Serving_Size,
    Carbs_per_Serving = row$Carbs_per_Serving,
    Source_Link = row$URL,
    scraped_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    status = res$status
  )
  message(sprintf("  [%3d/%d] %-60s %s",
                  i, nrow(urls_df),
                  substr(row$Product, 1, 60),
                  if (is.na(price_unit)) paste("FAIL:", res$status)
                  else sprintf("R%.2f%s", price_unit,
                               if (pack != 1) sprintf(" (R%.2f / %g)", res$price, pack) else "")))
  Sys.sleep(REQUEST_DELAY)
}

out <- bind_rows(results)
ok  <- sum(out$status == "ok", na.rm = TRUE)
message(sprintf("\nDone: %d/%d products priced.", ok, nrow(out)))

if (dry_run) {
  print(out)
} else {
  # merge with existing products.csv: keep prior row when scrape fails
  if (file.exists(OUT_PATH)) {
    prior <- read_csv(OUT_PATH, show_col_types = FALSE)
    failed <- out |> filter(is.na(Price_ZAR))
    if (nrow(failed)) {
      message("Carrying over prior prices for ", nrow(failed), " failed scrape(s).")
      out <- out |>
        rows_update(
          prior |> select(Product, Brand, Price_ZAR, scraped_at, status) |>
            semi_join(failed, by = c("Product", "Brand")) |>
            mutate(status = paste0("stale: ", status)),
          by = c("Product", "Brand")
        )
    }
  }
  write_csv(out, OUT_PATH)
  message("Wrote: ", OUT_PATH)
}
