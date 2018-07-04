#' Global Envelope Tests (GET)
#'
#' Global envelopes alias central regions and global envelope tests, including
#' global envelope (tests) for single and many functions and multivariate vectors,
#' adjusted global envelope tests, graphical functional one-way ANOVA
#'
#'
#' The \pkg{GET} library provides central regions (i.e. global envelopes) and global envelope tests.
#' The central regions can be constructed from (functional) data.
#' The tests are Monte Carlo tests, which demand simulations from the tested null model.
#' The methods are applicable for any multivariate vector data and functional data (after discretization).
#'
#' In the special case of point processes, the functions are typically estimators of summary functions.
#' The package supports the use of the R library \pkg{spatstat} for generating
#' simulations and calculating estimators of the chosen summary function, but alternatively these
#' can be done by any other way, thus allowing for any models/functions.
#'
#'
#' @section Key functions in \pkg{GET}:
#' \itemize{
#' \item \emph{Central regions} or \emph{global envelopes} or \emph{confidence bands}:
#' \code{\link{central_region}}.
#' E.g. growth curves of girls \code{\link[fda]{growth}}.
#' \itemize{
#'            \item First create a curve_set of the data.
#'
#'                  \code{
#'                    cset <- create_curve_set(list(r = as.numeric(row.names(growth$hgtf)),
#'                                                  obs = growth$hgtf))
#'                  }
#'            \item Then calculate 50\% central region
#'
#'                  \code{
#'                    cr <- central_region(cset, coverage = 0.5)
#'                  }
#'            \item Plot the result
#'
#'                  \code{
#'                    plot(cr)
#'                  }
#' }
#' It is also possible to do combined central regions for several sets of curves provided in a list
#' for the function, see examples in \code{\link{central_region}}.
#'
#' \item \emph{Global envelope tests}: \code{\link{global_envelope_test}} is the main function.
#' E.g.
#'
#' \code{X <- spruces # an example pattern from spatstat}
#'
#' Test complete spatial randomness (CSR):
#' \itemize{
#'            \item Use \code{\link[spatstat]{envelope}} to create nsim simulations
#'                  under CSR and to calculate the functions you want (below K-functions by Kest).
#'                  Important: use the option 'savefuns=TRUE' and
#'                  specify the number of simulations \code{nsim}.
#'
#'                  \code{
#'                    env <- envelope(X, nsim=999, savefuns=TRUE, fun=Kest,
#'                                    simulate=expression(runifpoint(X$n, win=X$window)))
#'                  }
#'            \item Perform the test
#'
#'                  \code{
#'                    res <- global_envelope_test(env)
#'                  }
#'            \item Plot the result
#'
#'                  \code{
#'                    plot(res)
#'                  }
#' }
#' It is also possible to do combined global envelope tests for several sets of curves provided in a list
#' for the function, see examples in \code{\link{global_envelope_test}}.
#' }
#'
#' \itemize{
#'  \item \emph{Functional ordering}: \code{\link{central_region}} and \code{\link{global_envelope_test}}
#'  are based on different measures for ordering the functions (or vectors) from
#'  the most extreme to the least extreme ones. The core functionality of calculating the measures
#'  is in the function \code{\link{forder}}, which can be used to obtain different measures for sets of
#'  curves. Usually there is no need to call \code{\link{forder}} directly.
#' \item \emph{Adjusted} global envelope tests for composite hypotheses
#' \itemize{
#'   \item \code{\link{dg.global_envelope}}, see a detailed example in \code{\link{saplings}}
#'   \item \code{\link{dg.combined_global_envelope}} for adjusted tests
#' }
#' \item \emph{One-way functional ANOVA}:
#'  \itemize{
#'   \item \emph{Graphical} functional ANOVA tests: \code{\link{graph.fanova}}
#'   \item rank envelope based on F-values: \code{\link{frank.fanova}}
#'  }
#' \item Deviation tests (for simple hypothesis): \code{\link{deviation_test}} (no gpaphical
#' interpretation)
#' }
#' See the help files of the functions for examples.
#'
#' @section Workflow for (single hypothesis) tests based on single functions:
#'
#' To perform a test you always first need to obtain the test function T(r)
#' for your data (T_1(r)) and for each simulation (T_2(r), ..., T_{nsim+1}(r)) in one way or another.
#' Given the set of the functions T_i(r), i=1,...,nsim+1, you can perform a test
#' by \code{\link{global_envelope_test}}.
#'
#' 1) The workflow utilizing \pkg{spatstat}:
#'
#' E.g. Say we have a point pattern, for which we would like to test a hypothesis, as a \code{\link[spatstat]{ppp}} object.
#'
#' \code{X <- spruces # an example pattern from spatstat}
#'
#' \itemize{
#'    \item Test complete spatial randomness (CSR):
#'          \itemize{
#'            \item Use \code{\link[spatstat]{envelope}} to create nsim simulations
#'                  under CSR and to calculate the functions you want.
#'                  Important: use the option 'savefuns=TRUE' and
#'                  specify the number of simulations \code{nsim}.
#'                  See the help documentation in \pkg{spatstat}
#'                  for possible test functions (if \code{fun} not given, \code{Kest} is used,
#'                  i.e. an estimator of the K function).
#'
#'                  Making 999 simulations of CSR
#'                  and estimating K-function for each of them and data
#'                  (the argument \code{simulate} specifies for \code{envelope} how to perform
#'                  simulations under CSR):
#'
#'                  \code{
#'                    env <- envelope(X, nsim=999, savefuns=TRUE,
#'                                    simulate=expression(runifpoint(X$n, win=X$window)))
#'                  }
#'            \item Perform the test
#'
#'                  \code{
#'                    res <- global_envelope_test(env)
#'                  }
#'            \item Plot the result
#'
#'                  \code{
#'                    plot(res)
#'                  }
#'          }
#'    \item A goodness-of-fit of a parametric model (composite hypothesis case)
#'          \itemize{
#'            \item Fit the model to your data by means of the function
#'                  \code{\link[spatstat]{ppm}} or \code{\link[spatstat]{kppm}}.
#'                  See the help documentation for possible models.
#'            \item Use \code{\link{dg.global_envelope}} to create nsim simulations
#'                  from the fitted model, to calculate the functions you want,
#'                  and to make an adjusted global envelope test.
#'                  See the detailed example in \code{\link{saplings}}.
#'            \item Plot the result
#'
#'                  \code{
#'                    plot(res)
#'                  }
#'          }
#'
#' }
#'
#' 2) The random labeling test with a mark-weighted K-function
#'\itemize{
#' \item Generate simulations (permuting marks) and estimate the chosen marked K_f-function for each pattern
#'       using the function \code{\link{random_labelling}} (requires R library \code{marksummary} available from
#'       \code{https://github.com/myllym/}).
#'
#'       \code{
#'       curve_set <- random_labelling(X, mtf_name = 'm', nsim=999, r_min=1.5, r_max=9.5)
#'       }
#' \item Then do the test and plot the result
#'
#'       \code{
#'       res <- global_envelope_test(curve_set); plot(res)
#'       }
#'}
#'
#' 3) The workflow when using your own programs for simulations:
#'
#' \itemize{
#' \item (Fit the model and) Create nsim simulations from the (fitted) null model.
#' \item Calculate the functions T_1(r), T_2(r), ..., T_{nsim+1}(r).
#' \item Use \code{\link{create_curve_set}} to create a curve_set object
#'       from the functions T_i(r), i=1,...,s+1.
#' \item Perform the test and plot the result
#'
#'       \code{res <- global_envelope_test(curve_set) # curve_set is the 'curve_set'-object you created}
#'
#'       \code{plot(res)}
#' }
#'
#' @section Functions for modifying sets of functions:
#' It is possible to modify the curve set T_1(r), T_2(r), ..., T_{nsim+1}(r) for the test.
#'
#' \itemize{
#' \item You can choose the interval of distances [r_min, r_max] by \code{\link{crop_curves}}.
#' \item For better visualisation, you can take T(r)-T_0(r) by \code{\link{residual}}.
#' Here T_0(r) is the expectation of T(r) under the null hypothesis.
#' \item You can use \code{\link{combine_curve_sets}} to create a \code{curve_set} object from
#' several \code{curve_set} or \code{\link[spatstat]{envelope}} objects. The object containing
#' many curves can be passed to \code{\link{global_envelope_test}}.
#' }
#'
#' The function \code{\link{envelope_to_curve_set}} can be used to create a curve_set object
#' from the object returned by \code{\link[spatstat]{envelope}}. An \code{envelope} object can also
#' directly be given to the functions mentioned above in this section.
#'
#' @section Number of simulations:
#'
#' Note that the recommended minimum number of simulations for the rank
#' envelope test based on a single function is nsim=2499, while for the
#' "erl", "qdir" and "st" global envelope tests and deviation tests,
#' a lower number of simulations can be used.
#'
#' Mrkvička et al. (2017) discusses the number of simulations for tests based on many functions.
#'
#' @author
#' Mari Myllymäki (mari.j.myllymaki@@gmail.com, mari.myllymaki@@luke.fi),
#' Henri Seijo (henri.seijo@@aalto.fi, henri.seijo@@iki.fi),
#' Tomáš Mrkvička (mrkvicka.toma@@gmail.com),
#' Pavel Grabarnik (gpya@@rambler.ru),
#' Ute Hahn (ute@@math.au.dk)
#'
#' @references
#' Myllymäki, M., Grabarnik, P., Seijo, H. and Stoyan. D. (2015). Deviation test construction and power comparison for marked spatial point patterns. Spatial Statistics 11: 19-34. doi: 10.1016/j.spasta.2014.11.004
#'
#' Myllymäki, M., Mrkvička, T., Grabarnik, P., Seijo, H. and Hahn, U. (2017). Global envelope tests for spatial point patterns. Journal of the Royal Statistical Society: Series B (Statistical Methodology), 79: 381–404. doi: 10.1111/rssb.12172
#'
#' Mrkvička, T., Myllymäki, M. and Hahn, U. (2017). Multiple Monte Carlo testing, with applications in spatial point processes. Statistics & Computing 27 (5): 1239-1255. doi: 10.1007/s11222-016-9683-9
#'
#' Mrkvička, T., Soubeyrand, S., Myllymäki, M., Grabarnik, P., and Hahn, U. (2016). Monte Carlo testing in spatial statistics, with applications to spatial residuals. Spatial Statistics 18, Part A: 40-53. doi: http://dx.doi.org/10.1016/j.spasta.2016.04.005
#'
#' @name GET
#' @docType package
#' @aliases GET-package GET
NULL
