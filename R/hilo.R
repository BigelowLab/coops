
#' Given a set of values compute the standard summary of 
#' \code{min, q25, median, mean, q75, max}
#' 
#' @export
#' @param x numeric vector of values
#' @param na.rm logical, if TRUE remove NA values before computing summaries
#' @return named vector of summary values
sixnum = function(x, probs = c(0.05, 0.1, 0.5, 0.9, 0.95), na.rm = TRUE){
  quantnames = as_q(probs)
  m = mean(x, na.rm = na.rm)
  r = stats::quantile(x, probs = probs, na.rm = na.rm)
  c(r, m) |>
    rlang::set_names(c(quantnames, "mean"))
}

#' Format probabilities in the qNNNN string format
#' 
#' @export
#' @param x num, probablities between 0-1, or formatted probabilities in the form qNNNN.
#' @return chr for `as_q()` and num for as_prob
as_q = function(x = c(0.05, 0.1, 0.5, 0.9, 0.95)){
  sprintf("q%0.4i", (x * 1000) |> as.integer())
}
#' @rdname as_q
#' @export
as_prob = function(x = as_q()){
  x = substring(x,2) |>
    as.numeric()
  x/1000
}

#' Retrieve the sixnum metrics for a CO-OPS high/low data frame
#' 
#' @export
#' @param x data frame as per [station_interpolate()]
#' @return a data frame with sixnums computed for value and datetime 
#'   differences (observed - predicted)
hilo_sixnum = function(x){
  x |>
    group_by(type) |>
    group_map(
      function(grp, key){
        qt = sixnum(grp$dtime)
        qv = sixnum(grp$dvalue)
        dplyr::tibble(
          type = key$type,
          name = c(rep("dtime", length(qt)), rep("dvalue", length(qv))),
          metric = c(names(qt), names(qv)),
          value = c(qt, qv) )
      }) |>
    dplyr::bind_rows()
}

#' Plot a surge data set (high and low differences between obs and preds)
#' 
#' @export
#' @param x data frame of high-low interpolates ala [station_interpolate()]
#' @param probs, num vector of probabilties to identify an event
#' @return data frame
plot_hilo = function(x = station_interpolate(), 
                      probs = c(0.05, 0.95)){
  
  my_seq = function(n){c(seq(from = 2, to = n), n)}
  gg = x |>
    dplyr::group_by(type) |>
    dplyr::group_map(
      function(grp, key){
        ltm = hilo_sixnum(grp) |>
          dplyr::filter(name == "dvalue",
                        metric %in% as_q(probs)) |>
          dplyr::mutate(prob = as_prob(.data$metric)) |>
          dplyr::arrange(.data$prob)
        grp = dplyr::arrange(grp, .data$obs_datetime) |>
          dplyr::mutate(xend = .data$obs_datetime[my_seq(dplyr::n())],
                        yend = .data$dvalue[my_seq(dplyr::n())],
                        event = case_when(
                          .data$dvalue <= ltm$value[1] ~ -1,
                          .data$dvalue >= ltm$value[2] ~ 1,
                          .default = 0) |>
                          factor(levels = c(1,0,-1),
                                 labels = c(">90th", "10th-90th", "<10th")))
        ggplot2::ggplot(data = grp,
                        mapping = ggplot2::aes(x = .data$obs_datetime,
                                               y = .data$dvalue)) +
          ggplot2::geom_point(mapping = ggplot2::aes(color = .data$event),
                              size = 1, alpha = 0.3 ) + 
          ggplot2::scale_color_manual(values = c(">90th" = "red", 
                                                 "10th-90th" = "grey75", 
                                                 "<10th" = "blue")) + 
          ggplot2::theme_light() + 
          ggplot2::theme(legend.position="none") + 
          ggplot2::labs(y = "Obs - Pred (m)",
                        title = c(H = "High Tide", L = "Low Tide")[grp$type[1]])
      }, .keep = TRUE) 
  gg
}





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