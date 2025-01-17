% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/nbGAM.R
\name{nbGAM}
\alias{nbGAM}
\title{Fit a negative-binomial GAM.}
\usage{
nbGAM(
  expr = NULL,
  pt = NULL,
  Y.offset = NULL,
  id.vec = NULL,
  penalize.spline = FALSE,
  spline.df = 5
)
}
\arguments{
\item{expr}{A vector of integer counts. Defaults to NULL.}

\item{pt}{A dataframe or vector of pseudotime values. Defaults to NULL.}

\item{Y.offset}{(Optional) An offset to be included in the final model fit. Defaults to NULL.}

\item{id.vec}{(Optional) A vector of subject IDs to be used in creating random intercepts in the GAM. Useful for comparing GAMs to GLMMs. Defaults to NULL.}

\item{penalize.spline}{(Optional) Should a P-spline be used to fit the GAM? Otherwise the default cubic basis spline is used instead. Defaults to FALSE.}

\item{spline.df}{(Optional) Degrees of freedom of the cubic basis spline. Unused if a P-spline is being fit, since it's estimated internally. Defaults to 5.}
}
\value{
An object of class \code{gamlss}
}
\description{
Fits a negative-binomial family GAM using a cubic basis spline on pseudotime. If data are multi-subject in nature, a random intercept is included for each subject.
}
\examples{
\dontrun{
nbGAM(expr_vec, pt_df)
nbGAM(expr_vec,
      pt = pt_df,
      id.vec = subject_ids,
      random.slopes = TRUE)
nbGAM(expr_vec,
      pt = pt_df,
      Y.offset = size_factor_vec,
      penalize.spline = TRUE,
      spline.df = 10)
}
}
\seealso{
\code{\link[gamlss]{gamlss}}

\code{\link[gamlss]{random}}

\code{\link[splines]{bs}}

\code{\link[gamlss]{pb}}

\code{\link[gamlss.dist]{NBI}}
}
\author{
Jack Leary
}
