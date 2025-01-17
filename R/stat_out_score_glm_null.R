#' Calculate part of the score statistic for a GLM.
#'
#' @name stat_out_score_glm_null
#' @author Jakub Stoklosa
#' @author David I. Warton
#' @author Jack Leary
#' @importFrom stats fitted.values
#' @importFrom MASS theta.mm
#' @description A function that calculates parts of the score statistic for GLMs only (it is used for the full path for forward selection).
#' @param Y : The response variable Defaults to NULL.
#' @param B_null : Design matrix under the null model. Defaults to NULL.
#' @return A list of values (mainly products of matrices) that make up the final score statistic calculation (required for another function).
#' @references Stoklosa, J., Gibb, H. and Warton, D.I. (2014). Fast forward selection for generalized estimating equations with a large number of predictor variables. \emph{Biometrics}, \strong{70}, 110--120.
#' @references Stoklosa, J. and Warton, D.I. (2018). A generalized estimating equation approach to multivariate adaptive regression splines. \emph{Journal of Computational and Graphical Statistics}, \strong{27}, 245--253.
#' @seealso \code{\link{stat_out}}
#' @seealso \code{\link{stat_out_score_gee_null}}

stat_out_score_glm_null <- function(Y = NULL, B_null = NULL) {
  # check inputs
  if (is.null(Y) || is.null(B_null)) { stop("Some inputs to stat_out_score_glm_null() are missing.") }
  # old version of dispersion estimate
  # ests <- gamlss::gamlss(Y ~ 1,
  #                        family = "NBI",
  #                        trace = FALSE,
  #                        data = NULL)
  N <- length(Y)
  mean_Y <- mean(Y)
  mu.est <- as.matrix(rep(mean_Y, N))  # faster than calling stats::fitted.values() actually
  # V.est <- mu.est * (1 + mu.est * (exp(ests$sigma.coef)))
  theta_hat <- MASS::theta.mm(y = Y,
                              mu = mean(Y),
                              dfr = N - 1)
  V.est <- mu.est * (1 + mu.est * (1 / theta_hat))  # Type I NB variance = mu (1 + mu * sigma); sigma = 1 / theta
  VS.est_list <- (Y - mu.est) / V.est
  temp_prod <- eigenMapMatMult(A = t(B_null),
                               B = diag(c(mu.est^2 / V.est)),
                               n_cores = 1)
  A_list_inv <- eigenMapMatMult(A = temp_prod,
                                B = B_null,
                                n_cores = 1)
  if (ncol(A_list_inv) == 1 && nrow(A_list_inv) == 1) {
    A_list <- 1 / A_list_inv
  } else {
    A_list <- chol2inv(chol(A_list_inv))
  }
  # B1_list <- t(B_null) %*% diag(c(mu.est^2 / V.est))
  B1_list <- eigenMapMatMult(A = t(B_null),
                             B = diag(c(mu.est^2 / V.est)),
                             n_cores = 1)
  res <- list(VS.est_list = VS.est_list,
              A_list = A_list,
              B1_list = B1_list,
              mu.est = mu.est,
              V.est = V.est)
  return(res)
}
