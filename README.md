CO-OOPS
================

An R language wrapper around
[CO-OPS](https://tidesandcurrents.noaa.gov/) handy
[API](https://api.tidesandcurrents.noaa.gov/api/prod/). While throughput
is throttled, it is an easy way to gather tide and current data
including observations.

> Someday we’ll add access to the [metadata
> API](https://api.tidesandcurrents.noaa.gov/mdapi/prod/#intro)

# Requirements

- [R v4.2+](https://www.r-project.org/)
- [rlang](https://CRAN.R-project.org/package=rlang)
- [dplyr](https://CRAN.R-project.org/package=dplyr)
- [readr](https://CRAN.R-project.org/package=readr)
- [httr](https://CRAN.R-project.org/package=httr)

# Installation

    remotes::install_github("BigelowLab/coops")

# Example

``` r
suppressPackageStartupMessages({
  library(coops)
  library(dplyr)
})

x = query_coops(station = "8418150", # Portland Maine
                begin_date = as.Date("2020-01-01"),
                end_date = as.Date("2020-12-31"),
                product = "hourly_height")
x
```

    ## # A tibble: 8,784 × 5
    ##    `Date Time`         `Water Level` Sigma     I     L
    ##    <dttm>                      <dbl> <dbl> <dbl> <dbl>
    ##  1 2020-01-01 00:00:00         0.984 0.016     0     0
    ##  2 2020-01-01 01:00:00         0.596 0.01      0     0
    ##  3 2020-01-01 02:00:00         0.513 0.006     0     0
    ##  4 2020-01-01 03:00:00         0.672 0.012     0     0
    ##  5 2020-01-01 04:00:00         1.08  0.015     0     0
    ##  6 2020-01-01 05:00:00         1.68  0.02      0     0
    ##  7 2020-01-01 06:00:00         2.26  0.015     0     0
    ##  8 2020-01-01 07:00:00         2.67  0.009     0     0
    ##  9 2020-01-01 08:00:00         2.82  0.005     0     0
    ## 10 2020-01-01 09:00:00         2.74  0.011     0     0
    ## # ℹ 8,774 more rows
