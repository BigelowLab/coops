#' For a given station retrieve predicted and observed high and low 
#' 
#' Arguments that are not used by [query_coops()] are prepended with a dot "."
#'
#' @export
#' @param station chr the station ID
#' @param begin_date Date start date
#' @param end_date Date end date
#' @param ... other arguments for [build_query()]
#' @param .join chr one of "interpolate" or "merge" (default).
#'   "interpolate" will interpolate the predicted extreme to the closest
#'   observed extreme (ie one timestamp two metrics).  "merge" will 
#'   simply merge the two datasets with no interpolation
#' @param .sleep num, number of seconds to pause between each request
#' @param .verbose logical, should the url be printed for each request
#' @param .tolerance num, record matching tolerance in number of seconds, 
#'  ignored unless `.join` is "interpolate". For example, a value of 600 
#'  means +/-600 seconds (10 minutes)
#' @return data frame
station_high_low = function(station = "8418150",
                          begin_date = as.Date("1970-01-01"),
                          end_date = Sys.Date(),
                          ...,
                          .join = "merge",
                          .sleep = 2,
                          .verbose = FALSE,
                          .tolerance = 7200){
  
  if (FALSE){
    station = "8418150"
    begin_date = as.Date("1970-01-01")
    end_date = Sys.Date()
    join = "merge"
    .sleep = 2
    .verbose = FALSE
    .tolerance = 7200
  }
  
  z = dplyr::tibble(date = seq(from = begin_date, to = end_date, by = "day"),
                    year = format(date, "%Y"))
  
  preds =  z |>
    dplyr::group_by(.data$year) |>
    dplyr::group_map(
      function(grp, row){
        r = query_coops(station = station[1], 
                    begin_date = dplyr::slice(grp,1) |> dplyr::pull(),
                    end_date = dplyr::slice_tail(grp, n=1) |> dplyr::pull(),
                    product = "predictions", 
                    interval = "hilo",
                    format = "csv",
                    verbose = .verbose) #,
                    #...)
         Sys.sleep(.sleep)
         return(r)
      }) |>
    dplyr::bind_rows() |>
    dplyr::rename(datetime = "Date Time",
                  value = "Prediction",
                  type = "Type") |>
    dplyr::mutate(type = substring(.data$type, 1, 1),
                  datetime = ensure_datetime(.data$datetime)) |> 
    dplyr::mutate(group = "pred", .before = 1)|>
    
    dplyr::arrange(.data$datetime) |>
    dplyr::select(-dplyr::any_of(c("I", "L")))

  obs =  z |>
    dplyr::group_by(.data$year) |>
    dplyr::group_map(
      function(grp, row){
        r = query_coops(station = station[1], 
                    begin_date = dplyr::slice(grp,1) |> dplyr::pull(),
                    end_date = dplyr::slice_tail(grp, n=1) |> dplyr::pull(),
                    product = "high_low",
                    format = "csv",
                    verbose = .verbose)#,
                    #...)
        Sys.sleep(.sleep)
        return(r)
      }) |>
    dplyr::bind_rows() |>
    dplyr::rename(datetime = "Date Time",
                  value = "Water Level",
                  type = "TY") |>
    dplyr::mutate(type = substring(.data$type, 1, 1)) |> 
    dplyr::mutate(group = "obs", .before = 1) |>
    dplyr::arrange(.data$datetime) |>
    dplyr::select(-dplyr::any_of(c("I", "L")))
 
  if (tolower(.join[1]) == "merge"){
    x = dplyr::bind_rows(preds, obs) |>
      dplyr::arrange(.data$datetime)
  } else {
    x = station_interpolate(x, .tolerance = .tolerance)
  }
  return(x)
}

#' Interpolate a station such that for each observation we
#' find the difference from the prediction
#' 
#' @export
#' @param x data frame output from [station_high_low]
#' @param .tolerance num, tolerance in seconds for matching
#'  predictions against observations.  
#' @return data frame 
station_interpolate = function(x = station_high_low(begin_date = as.Date("1990-01-01"),
                                                    end_date = as.Date("1990-01-01") + (365 * 3),
                                                    .verbose = FALSE), 
                               .tolerance = 7200 ){
  
  z = x |>
    dplyr::select(-dplyr::any_of(c("I", "L"))) |>
    dplyr::group_by(.data$type) |>
    dplyr::group_map(
      function(grp, key1){
        
        obs = dplyr::filter(grp, group == "obs")
        preds = dplyr::filter(grp, group == "pred")
        
        obs |> 
          dplyr::rowwise() |>
          dplyr::group_map(
            function(ob, key2){
              p = preds |>
                dplyr::mutate(dt = ob$datetime - .data$datetime) |>
                dplyr::filter(abs(.data$dt) <= .tolerance) |>
                dplyr::slice(which.min(abs(.data$dt))[1])
              if (nrow(p) > 0){
                r = dplyr::tibble(type = key1$type,
                                  obs_datetime = ob$datetime,
                                  pred_datetime = p$datetime,
                                  dtime = obs_datetime - pred_datetime,
                                  obs_value = ob$value,
                                  pred_value = p$value,
                                  dvalue = obs_value - pred_value)
              } else {
                r = NULL
              }
              r
            })
      } ) |>
    dplyr::bind_rows() |>
    dplyr::mutate(dtime = as.numeric(.data$dtime))
  
  z
}