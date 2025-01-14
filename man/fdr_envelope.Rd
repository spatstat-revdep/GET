% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/fdr.r
\name{fdr_envelope}
\alias{fdr_envelope}
\title{The FDR envelope}
\usage{
fdr_envelope(
  curve_sets,
  alpha = 0.05,
  alternative = c("two.sided", "less", "greater"),
  algorithm = c("IATSE", "ATSE"),
  lower = NULL,
  upper = NULL
)
}
\arguments{
\item{curve_sets}{A \code{curve_set} (see \code{\link{create_curve_set}}) or an
\code{envelope} object of \pkg{spatstat} containing the observed function
and the functions from which the envelope is to be constructed.
Alternatively, a list of appropriate objects can be given.}

\item{alpha}{The significance level. The 100(1-alpha)\% global envelope will be calculated.
If a vector of values is provided, the global envelopes are calculated for each value.}

\item{alternative}{A character string specifying the alternative hypothesis.
Must be one of the following: "two.sided" (default), "less" or "greater".
The last two options only available for types \code{'rank'}, \code{'erl'},
\code{'cont'} and \code{'area'}.}

\item{algorithm}{Either "IATSE" or "ATSE" standing for the iteratively adaptive two-stage
envelope and the adaptive two-stage envelope, respectively, see Mrkvička and Myllymäki (2022).}

\item{lower}{A single number (or a vector of suitable length) giving a lower bound
for the functions. Used only for the extension, see Mrkvička and Myllymäki (2022, p. 6).}

\item{upper}{A single number (or a vector of suitable length) giving an upper bound
for the functions.}
}
\description{
Calculate the FDR envelope based on the ATSE or IATSE algorithm
of Mrkvička and Myllymäki (2022).
}
\examples{
# A GLM example
data(rimov)
\donttest{nsim <- 1000 # Number of simulations}
\dontshow{nsim <- 20}
res <- graph.flm(nsim=nsim,
                 formula.full = Y~Year,
                 formula.reduced = Y~1,
                 typeone = "fdr",
                 curve_sets = list(Y=rimov),
                 factors = data.frame(Year = 1979:2014))
plot(res)

}
\references{
Mrkvička and Myllymäki (2022). False discovery rate envelopes. arXiv:2008.10108 [stat.ME]
}
