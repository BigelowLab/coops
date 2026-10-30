#' Make sure a datetime vector is datetime (POSIXct) format
#' 
#' @export
#' @param x vector of (hopefully) datetime data
#' @return vector of datetime (POSIXct) data
ensure_datetime = function(x){
  if (!inherits(x, "POSIXt")) {
    klass = class(x)[1]
    x = switch(klass, 
       "numeric" = as.POSIXct(x, origin = as.POSICxt("1970-01-01 00:00:00"), tz = "UTC"),
       as.POSIXct(x, tz = "UTC"))
  }
  x
}


#' Given a data frame, determine the shorthand column types
#'
#' @export
#' @param data frame as returned by [query_coops()]
#' @return chr, shortname codes for data types
col_typer = function(x = query_coops(station = "8418150", 
                                     begin_date = as.Date("2020-01-01"),
                                     end_date = as.Date("2020-01-07"),
                                     product = "high_low", 
                                     format = "csv")){
  
  lut = column_type_codes()
  type = sapply(x, function(int) class(int)[1])
  lut[unname(type)] |> paste(collapse = "")
}

#' Retrieve a named vector of column types in longname = shortname form.
#' 
#' @export
#' @return a named vector of longname = shortname for common data types
column_type_codes = function(){
    c(logical = "l",
    integer = "i",
    numeric = "n",
    double = "d",
    character ="c",
    factor ="f",
    Date = "D",
    POSIXt = "T",
    POSIXct = "T")
}
