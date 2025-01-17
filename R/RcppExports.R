# Generated by using Rcpp::compileAttributes() -> do not edit by hand
# Generator token: 10BE3573-1514-4C36-9D1C-5A225CD40393

#' binary (XOR) distance coding for char and bool factors
#'
#' @param data data frame
#' @export
binaryCodingCpp <- function(data, w) {
    .Call(`_Cookie_binaryCodingCpp`, data, w)
}

#' hamming distance coding for numerical factors
#'
#' @param data data frame
#' @export
hammingCodingCpp <- function(data) {
    .Call(`_Cookie_hammingCodingCpp`, data)
}

