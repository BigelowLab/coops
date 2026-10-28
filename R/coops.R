#' Query CO-OPS for data
#' 
#' @export
#' @param station chr, the staion ID
#' @param ... other arguments for [build_query()]
#' @return response data - possibly empty
query_coops = function(station = "8418150",
                       ...){
  
  uri = build_query(station = station, ...)
  resp = httr::GET(uri)
  unpack_response(resp)
}

#' Unpack a response
#' 
#' @export
#' @param x a response variable from [httr::GET()]
#' @return varies
unpack_response = function(x){
  
  r = switch(httr::http_type(x),
    "text/comma-separated-values" = {
      txt = httr::content(x, encoding = "UTF-8")
      ss = scan(text = txt,
                what = "character",
                strip.white = TRUE,
                sep = "\n",
                quiet = TRUE)
      nms = strsplit(ss[1], ",", fixed = TRUE)[[1]] |>
        trimws(which = "both")
      if (any(grepl("Error", txt, fixed = TRUE))){
        r = rep(NA_character_, length(nms)) |>
          as.list() |>
          rlang::set_names(nms) |>
          dplyr::as_tibble() |>
          dplyr::slice(0)
      } else {
        r = readr::read_csv(I(txt), 
                            show_col_types = FALSE)
      }
      r
    },
    stop("type not known:", httr::http_type(x)) 
  )
  r
}

#' The root URL for data retrieval
#' @export
#' @return chr, the root URL
query_root_url = function(){
  "https://api.tidesandcurrents.noaa.gov/api/prod/datagetter?"
}

#' Build a query 
#' 
#' @export
#' @param ... named arguments to build the query
#' @param units chr, either "english" or "metric" (default)
#' @param datum chr, the tide height datum byt default relative to 
#'   mean low low water "MLLW"
#' @param time_zone chr, by default "gmt"
#' @param format chr, by default "csv" but "json" and "xml" could be ok someday
#' @param application chr, user identifier, helpful if debugging
#' @param root chr, the root query URL
#' @return url string suitable for [httr::GET()]
build_query = function(...,
                       units = "metric",
                       datum = "MLLW",
                       time_zone = "gmt",
                       format = "csv",
                       application="BLOS_coops",
                       root = query_root_url()){
  
 params = list(...) |> 
   qualify_params()
 params$units <- units[1]
 params$datum <- datum[1]
 params$time_zone <- time_zone[1]
 params$application <- application[1]
 params$format <- format[1]
 
 p = sapply(names(params),
            function(nm){
              paste0(nm, "=", params[[nm]])
            }) |>
   paste(collapse = "&")

 paste0(root,p)
}

#' Quality check on some parameters
#' 
#' @export
#' @param x a named list of parameters
#' @return the input list possibly modified to make acceptable strings
#'   of dates and the like
qualify_params = function(x){
  nms = names(x)
  if ("begin_date" %in% nms){
    x[["begin_date"]] = format_datetime(x[["begin_date"]])
  }
  if ("end_date" %in% nms){
    x[["end_date"]] = format_datetime(x[["end_date"]])
  }
  
  x
}

#' Format date and date-time inputs from user
#' 
#' @export
#' @param x chr, Date or POSIX object
#' @return if Date or POSIX then a formatted string, otherwise
#'   the input is returned as is
format_datetime = function(x){
  if (inherits(x, "Date")){
    x = format(x, "%Y%m%d")
  } else if (inherits(x, "POSIXt")){
    x = format(x, "%Y%m%d %H:%M")
  }
  x
}
