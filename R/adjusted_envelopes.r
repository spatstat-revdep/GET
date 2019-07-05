# A helper function to generate simulated functions from "X" using given functions/arguments,
# when X is a ppp or model object of spatstat.
#
# a) If X is a point pattern (object of class "ppp"), then CSR is simulated (with variable number of points).
# b) If X is a fitted point process model (object of class "ppm" or "kppm"),
# the simulated model is that model (by spatstat).
# If testfuns is given, then also several different test functions can be calculated.
#' @importFrom spatstat envelope
funcs_from_X_and_funs <- function(X, nsim, testfuns=NULL, ...,
                                  savepatterns=FALSE, verbose=FALSE, calc_funcs=TRUE) {
  extraargs <- list(...)
  nfuns <- length(testfuns)
  if(nfuns < 1) nfuns <- 1
  for(i in 1:nfuns)
    if(any(names(extraargs) %in% names(testfuns[[i]])))
      stop(paste("formal argument(s) \"", names(extraargs)[which(names(extraargs) %in% names(testfuns[[i]]))], "\" matched by multiple actual arguments\n", sep=""))

  X.ls <- NULL
  # Simulations
  # Calculate the first test functions and generate simulations
  X.ls[[1]] <- do.call(envelope, c(list(Y=X, nsim=nsim, simulate=NULL),
                                        testfuns[[1]],
                                        list(savefuns=TRUE, savepatterns=savepatterns, verbose=verbose),
                                        extraargs))
  # More than one test function, calculate the rest if calc_funcs==TRUE
  if(calc_funcs & nfuns > 1) {
    simpatterns <- attr(X.ls[[1]], "simpatterns")
    for(i in 2:nfuns) {
      X.ls[[i]] <- do.call(envelope, c(list(Y=X, nsim=nsim, simulate=simpatterns),
                                            testfuns[[i]],
                                            list(savefuns=TRUE, savepatterns=FALSE, verbose=verbose),
                                            extraargs))
    }
  }
  X.ls
}

# A helper function to perform simulations for the GET.composite
#' @importFrom spatstat is.ppm is.kppm is.lppm is.slrm
#' @importFrom spatstat is.ppp
#' @importFrom spatstat update.ppm update.kppm update.lppm update.slrm
#' @importFrom parallel mclapply
adj.simulate <- function(X, nsim = 499, nsimsub = nsim,
                         simfun=NULL, fitfun=NULL, calcfun=function(X) { X },
                         testfuns=NULL, ..., verbose=TRUE, mc.cores=1L) {
  # Check if X is a (ppp) model object of spatstat
  Xispppmodel <- is.ppm(X) || is.kppm(X) || is.lppm(X) || is.slrm(X)

  # Case 1: fitfun, simfun, calcfun provided
  # Model fitted by fitfun, simulated by simfun; X can be general
  if(!is.null(fitfun) & !is.null(simfun)) {
    cat("Note: Model to be fitted by fitfun(X), simulations by simfun and calcfun;\n",
        "simfun should accept the object returned by fitfun as its argument.\n",
        "calcfun should accept the object returned by simfun as its argument.\n")
    # Fit the model to X
    simfun.arg <- fitfun(X) # fitted model to be passed to simfun
    # Generate nsim simulations by the given function using the fitted model
    stage1_cset_ls <- replicate(n=nsimsub, expr=simfun(simfun.arg), simplify=FALSE) # list of data objects
    stage1_cset_ls <- sapply(stage1_cset_ls, FUN=calcfun, simplify=TRUE) # matrix of functions
    stage1_cset_ls <- list(create_curve_set(list(r=1:nrow(stage1_cset_ls), obs=calcfun(X), sim_m=stage1_cset_ls)))
    # Create another set of simulations to be used to estimate the second-state p-value
    # following Baddeley et al. (2017).
    Xsims <- replicate(n=nsim, expr=simfun(simfun.arg), simplify=FALSE) # list of data objects
    loopfun <- function(rep) {
      # Fit the model to the simulated pattern Xsims[[rep]]
      simfun.arg <- fitfun(Xsims[[rep]])
      # Generate nsimsub simulations from the fitted model
      cset <- replicate(n=nsimsub, expr=simfun(simfun.arg), simplify=FALSE) # list of data objects
      cset <- sapply(cset, FUN=calcfun, simplify=TRUE) # matrix of functions
      list(create_curve_set(list(r=1:nrow(cset), obs=calcfun(X), sim_m=cset)))
    }
    stage2_csets_lsls <- parallel::mclapply(X=1:nsim, FUN=loopfun, mc.cores=mc.cores)
  }
  # Case 2: simfun or fitfun not provided; X should be a ppp or model object of spatstat
  # a) If X is a ppp object, the tested model is CSR
  # b) If X is a model object of spatstat, then spatstat is used for fitting and simulation.
  else {
    if(!is.ppp(X) & !Xispppmodel) stop("fitfun or simfun not provided and X is not a ppp nor a fitted model object of spatstat.\n")
    if(Xispppmodel) cat("X is a fitted model object of spatstat;\n using spatstat to simulate the model and calculate the test functions.\n")
    else
      cat("Note: \'simfun\' and/or \'fitfun\' not provided and \'X\' is a ppp object of spatstat.\n",
          "The spatstat's function \'envelope\' is used for simulations and model fitting, \n",
          "and CSR is tested (with intensity parameter).\n")
    # Create simulated functions from the given model
    stage1_cset_ls <- funcs_from_X_and_funs(X, nsim=nsimsub, testfuns=testfuns, ...,
                                            savepatterns=FALSE, verbose=verbose, calc_funcs=TRUE)
    # Create another set of simulations to be used to estimate the second-state p-value
    # following Baddeley et al. (2017).
    simpatterns <- attr(funcs_from_X_and_funs(X, nsim=nsim, testfuns=testfuns, ...,
                                              savepatterns=TRUE, verbose=verbose, calc_funcs=FALSE)[[1]],
                        "simpatterns")
    # For each of the simulated patterns in 'simpatterns', fit the model and
    # create nsim simulations from it
    loopfun <- function(rep) {
      # Create a simulation
      Xsim <- simpatterns[[rep]]
      if(Xispppmodel)
        switch(class(X)[1],
               ppm = {
                 Xsim <- update.ppm(X, Xsim)
               },
               kppm = {
                 Xsim <- update.kppm(X, Xsim)
               },
               lppm = {
                 Xsim <- update.lppm(X, Xsim)
               },
               slrm = {
                 Xsim <- update.slrm(X, Xsim)
               })
      # Create simulations from the given model and calculate the test functions
      funcs_from_X_and_funs(Xsim, nsim=nsimsub, testfuns=testfuns, ...,
                            savepatterns=FALSE, verbose=verbose, calc_funcs=TRUE)
    }
    stage2_csets_lsls <- mclapply(X=1:nsim, FUN=loopfun, mc.cores=mc.cores)
  }
  list(X=stage1_cset_ls, X.ls=stage2_csets_lsls)
}

GE.attr <- function(x, name = "p", ...) {
  if(inherits(x, c("global_envelope", "global_envelope_2d"))) a <- attr(x, name)
  if(inherits(x, c("combined_global_envelope", "combined_global_envelope_2d"))) a <- attr(attr(x, "level2_ge"), name)
  a
}

# A helper function to make a global envelope test for the purposes of GET.composite
# @param curve_sets_ls A list of curve_sets.
# @inheritParams GET.composite
adj.GET_helper <- function(curve_sets, type, alpha, alternative, ties, probs, MrkvickaEtal2017, ..., save.envelope=FALSE) {
  if(length(curve_sets) > 1 & MrkvickaEtal2017 & type %in% c("st", "qdir")) {
    global_envtest <- combined_scaled_MAD_envelope(curve_sets, type=type, alpha=alpha, probs=probs, ...)
  }
  else {
    global_envtest <- global_envelope_test(curve_sets, type=type, alpha=alpha,
                                           alternative=alternative, ties=ties, probs=probs, ...)
  }
  res <- structure(list(stat = as.numeric(GE.attr(global_envtest, "k")[1]), pval = GE.attr(global_envtest, "p")),
                   class = "adj_GET_helper")
  if(save.envelope) attr(res, "envelope_test") <- global_envtest
  res
}

#' Adjusted global envelope tests
#'
#' Adjusted global envelope tests for composite null hypothesis.
#'
#'
#' The specification of X, X.ls, fitfun, simfun is important:
#' \itemize{
#' \item If \code{X.ls} is provided, then the global envelope test is calculated based on
#' functions in these objects. \code{X} should be a \code{curve_set} (see \code{\link{create_curve_set}})
#' or an \code{\link[spatstat]{envelope}} object including the observed function and simulations
#' from the tested model. \code{X.ls} should be a list of \code{curve_set} or
#' \code{\link[spatstat]{envelope}} objects, where each component contains an "observed"
#' function f that has been simulated from the model fitted to the data and the simulations
#' that have been obtained from the same model that has been fitted to the "observed" f.
#' The user has the responsibility that the functions have been generated correctly,
#' the test is done based on these provided simulations. See the examples.
#' \item Otherwise, if \code{simfun} and \code{fitfun} are provided, \code{X} can be general.
#' The function \code{fitfun} is used for fitting the desired model M and the function \code{simfun}
#' for simulating from a fitted model M. These functions should be coupled with each other such
#' that the object returned by \code{fitfun} is directly accepted as the (single) argument in
#' \code{simfun}.
#' In the case, that the global envelope should not be calculated directly for \code{X} (\code{X} is
#' not a function), \code{calcfun} can be used to specify how to calculate the function from
#' \code{X} and from simulations generated by \code{simfun}.
#' Special attention is needed in the correct specification of the functions, see examples.
#'  \item Otherwise, \code{X} should be either a fitted (point process) model object or a \code{\link{ppp}}
#'   object of the R library \pkg{\link{spatstat}}.
#' \itemize{
#'   \item If \code{X} is a fitted (point process) model object of the R library \pkg{\link{spatstat}},
#' then the simulations from this model are generated and summary functions for testing calculated
#' by \code{\link[spatstat]{envelope}}. Which summary function to use and how to calculate it,
#' can be passed to \code{\link[spatstat]{envelope}} either in \code{...} or \code{testfuns}.
#' Unless otherwise specified the default function of \code{\link[spatstat]{envelope}},
#' i.g. the K-function, is used. The argument \code{testfuns} should be used to specify the
#' test functions in the case where one wants to base the test on several test functions.
#'   \item If \code{X} is a \code{\link[spatstat]{ppp}} object, then \code{\link[spatstat]{envelope}}
#' is used for simulations and model fitting and the complete spatial randomness (CSR) is tested
#' (with intensity parameter).
#' }
#' }
#'
#' For the rank envelope test, the global envelope test is the test described in
#' Myllymäki et al. (2017) with the adjustment of Baddeley et al. (2017).
#' For other test types, the test (also) uses the two-stage procedure of Dao and Genton (2014) with
#' the adjustment of Baddeley et al. (2017).
#'
#' See examples also in \code{\link{saplings}}.
#'
#' @param X An object containing the data in some form.
#' A \code{curve_set} (see \code{\link{create_curve_set}}) or an \code{\link[spatstat]{envelope}}
#' object, as the \code{curve_sets} argument of \code{\link{global_envelope_test}}
#' (need to provide \code{X.ls}), or
#' a fitted point process model of \pkg{\link{spatstat}} (e.g. object of class \code{\link[spatstat]{ppm}} or
#' \code{\link[spatstat]{kppm}}), or a point pattern object of class \code{\link[spatstat]{ppp}},
#' or another data object (need to provide \code{simfun}, \code{fitfun}, \code{calcfun}).
#' @param X.ls A list of objects as \code{curve_sets} argument of \code{\link{global_envelope_test}},
#' giving the second stage simulations, see details.
#' @param nsim The number of simulations to be generated in the primary test.
#' Ignored if \code{X.ls} provided.
#' @param nsimsub Number of simulations in each basic test. There will be \code{nsim} repetitions
#' of the basic test, each involving \code{nsimsub} simulated realisations.
#' Total number of simulations will be nsim * (nsimsub + 1).
#' @param simfun A function for generating simulations from the null model. If given, this function
#' is called by \code{replicate(n=nsim, simfun(simfun.arg), simplify=FALSE)} to make nsim
#' simulations. Here \code{simfun.arg} is obtained by \code{fitfun(X)}.
#' @param fitfun A function for estimating the parameters of the null model.
#' The function should return the fitted model in the form that it can be directly
#' passed to \code{simfun} as its argument.
#' @param calcfun A function for calculating a summary function from a simulation of the model.
#' The default is the identity function, i.e. the simulations from the model are functions themselves.
#' The use of \code{calcfun} is still experimental. Preferably provide \code{X} and
#' \code{X.ls} instead, if \code{X} is not a point pattern or fitted point process model object
#' of \pkg{\link{spatstat}}.
#' @param testfuns A list of lists of parameters to be passed to \code{\link[spatstat]{envelope}}
#' if \code{X} is a point pattern of a fitted point process model of \pkg{\link{spatstat}}.
#' A list of parameters should be provided for each test function that is to be used in the
#' combined test.
#' @param ... Additional parameters to \code{\link[spatstat]{envelope}} in the case where only one test
#' function is used. In that case, this is an alternative to providing the parameters in the argument
#' testfuns. If \code{\link[spatstat]{envelope}} is also used to generate simulations under the null
#' hypothesis (if simfun not provided), then also recall to specify how to generate the simulations.
#' @inheritParams global_envelope_test
#' @param r_min The minimum argument value to include in the test.
#' @param r_max The maximum argument value to include in the test.
#' in calculating functions by \code{\link[spatstat]{envelope}}.
#' @param take_residual Logical. If TRUE (needed for visual reasons only) the mean of the simulated
#' functions is reduced from the functions in each first and second stage test.
#' @param save.cons.envelope Logical flag indicating whether to save the unadjusted envelope test results.
#' @param savefuns Logical flag indicating whether to save all the simulated function values.
#' Similar to the same argument of \code{\link[spatstat]{envelope}}.
#' @param verbose Logical flag indicating whether to print progress reports during the simulations.
#' Similar to the same argument of \code{\link[spatstat]{envelope}}.
#' @param MrkvickaEtal2017 Logical. If TRUE, type is "st" or "qdir" and several test functions are used,
#' then the combined scaled MAD envelope presented in Mrkvička et al. (2017) is calculated. Otherwise,
#' the two-step procedure described in \code{\link{global_envelope_test}} is used for combining the tests.
#' Default to FALSE. The option kept for historical reasons.
#' @param mc.cores The number of cores to use, i.e. at most how many child processes will be run simultaneously.
#' Must be at least one, and parallelization requires at least two cores. On a Windows computer mc.cores must be 1
#' (no parallelization). For details, see \code{\link{mclapply}}, for which the argument is passed.
#' Parallelization can be used in generating simulations and in calculating the second stage tests.
#' @return An object of class \code{global_envelope} or \code{combined_global_envelope}, which can be
#' printed and plotted directly. See \code{\link{global_envelope_test}}.
#' @references
#' Myllymäki, M., Mrkvička, T., Grabarnik, P., Seijo, H. and Hahn, U. (2017). Global envelope tests for spatial point patterns. Journal of the Royal Statistical Society: Series B (Statistical Methodology), 79: 381-404. doi: 10.1111/rssb.12172
#'
#' Mrkvička, T., Myllymäki, M. and Hahn, U. (2017) Multiple Monte Carlo testing, with applications in spatial point processes. Statistics & Computing 27(5): 1239-1255. DOI: 10.1007/s11222-016-9683-9
#'
#' Dao, N.A. and Genton, M. (2014). A Monte Carlo adjusted goodness-of-fit test for parametric models describing spatial point patterns. Journal of Graphical and Computational Statistics 23, 497-517.
#'
#' Baddeley, A., Hardegen, A., Lawrence, T., Milne, R. K., Nair, G. and Rakshit, S. (2017). On two-stage Monte Carlo tests of composite hypotheses. Computational Statistics and Data Analysis 114: 75-87. doi: http://dx.doi.org/10.1016/j.csda.2017.04.003
#' @seealso \code{\link{global_envelope_test}}, \code{\link{plot.global_envelope}}, \code{\link{saplings}}
#' @export
#' @aliases dg.global_envelope_test
#' @importFrom parallel mclapply
#' @importFrom stats quantile
#' @examples
#' \donttest{
#' if(require("spatstat", quietly=TRUE)) {
#'   data(saplings)
#'
#'   # First choose the r-distances
#'   rmin <- 0.3; rmax <- 10; rstep <- (rmax-rmin)/500
#'   r <- seq(0, rmax, by=rstep)
#'
#'   # Number of simulations
#'   nsim <- 19 # Increase nsim for serious analysis!
#'
#'   # Option 1: Give the fitted model object to GET.composite
#'   #--------------------------------------------------------
#'   # This can be done and is preferable when the model is
#'   # a point process model of spatstat.
#'   # 1. Fit the Matern cluster process to the pattern
#'   # (using minimum contrast estimation with the K-function)
#'   M1 <- kppm(saplings~1, clusters = "MatClust", statistic="K")
#'   summary(M1)
#'   # 2. Make the adjusted global area rank envelope test using the L(r)-r function
#'   adjenvL <- GET.composite(X = M1, nsim = nsim,
#'               testfuns = list(L = list(fun="Lest", correction="translate",
#'                              transform = expression(.-r), r=r)), # passed to envelope
#'               type = "area", r_min=rmin, r_max=rmax)
#'   # Plot the test result
#'   plot(adjenvL)
#'
#'   # Option 2: Generate the simulations "by yourself"
#'   #-------------------------------------------------
#'   # and provide them as curve_set or envelope objects
#'   # Preferable when you want to have a control
#'   # on the simulations yourself.
#'   # 1. Fit the model
#'   M1 <- kppm(saplings~1, clusters = "MatClust", statistic="K")
#'   # 2. Generate nsim simulations by the given function using the fitted model
#'   X <- envelope(M1, nsim=nsim, savefuns=TRUE,
#'                 fun="Lest", correction="translate",
#'                 transform = expression(.-r), r=r)
#'   plot(X)
#'   # 3. Create another set of simulations to be used to estimate
#'   # the second-state p-value (as proposed by Baddeley et al., 2017).
#'   simpatterns2 <- simulate(M1, nsim=nsim)
#'   # 4. Calculate the functions for each pattern
#'   simf <- function(rep) {
#'     # Fit the model to the simulated pattern Xsims[[rep]]
#'     sim_fit <- kppm(simpatterns2[[rep]], clusters = "MatClust", statistic="K")
#'     # Generate nsim simulations from the fitted model
#'     envelope(sim_fit, nsim=nsim, savefuns=TRUE,
#'              fun="Lest", correction="translate",
#'              transform = expression(.-r), r=r)
#'   }
#'   X.ls <- parallel::mclapply(X=1:nsim, FUN=simf, mc.cores=1) # list of envelope objects
#'   # 5. Perform the adjusted test
#'   res <- GET.composite(X=X, X.ls=X.ls, type="area",
#'                       r_min=rmin, r_max=rmax)
#'   plot(res)
#'
#'   # Option 2: Generate the simulations "by yourself"
#'   # Writing with for-loops (instead of envelope calls)
#'   # Serves as an example for non-spatstat models.
#'   #-------------------------------------------------
#'   # 1. Fit the model
#'   M1 <- kppm(saplings~1, clusters = "MatClust", statistic="K")
#'   # Generate nsim simulations by the given function using the fitted model
#'   # 2. Simulate a sample from the fitted null model and
#'   # compute the test vectors for data and each simulation
#'   nsim <- nsimsub <- 19 # Number of simulations
#'   # Observed function
#'   obs.L <- Lest(saplings, correction = "translate", r = r)
#'   obs <- obs.L[['trans']] - r
#'   # Simulated functions
#'   sim <- matrix(nrow = length(r), ncol = nsimsub)
#'   for(i in 1:nsimsub) {
#'     sim.X <- simulate(M1)[[1]]
#'     sim[, i] <- Lest(sim.X, correction = "translate", r = r)[['trans']] - r
#'   }
#'   # Create a curve_set
#'   X <- create_curve_set(list(r = r, obs = obs, sim_m = sim))
#'   # 3. Simulate another sample from the fitted null model.
#'   sims2 <- simulate(M1, nsim=nsim) # list of simulations
#'   # 4. Fit the null model to each of the patterns,
#'   # simulate a sample from the null model,
#'   # and compute the test vectors for all.
#'   X.ls <- list()
#'   for(rep in 1:nsim) {
#'     M2 <- kppm(sims2[[rep]], clusters = "LGCP", statistic="K")
#'     obs2 <- Lest(sims2[[rep]], correction = "translate", r = r)[['trans']] - r
#'     sim2 <- matrix(nrow = length(r), ncol = nsimsub)
#'     for(i in 1:nsimsub) {
#'       sim2.X <- simulate(M2)[[1]]
#'       sim2[, i] <- Lest(sim2.X, correction = "translate", r = r)[['trans']] - r
#'     }
#'     X.ls[[rep]] <- create_curve_set(list(r = r, obs = obs2, sim_m = sim2))
#'   }
#'   # 5. Perform the adjusted test
#'   res <- GET.composite(X=X, X.ls=X.ls, type="area",
#'                       r_min=rmin, r_max=rmax)
#'   plot(res)
#'
#'   # Option 3: Provide fitfun and simfun functions
#'   #----------------------------------------------
#'   # fitfun = a function to fit the model
#'   # simfun = a function to make a simulation from the model
#'   # calcfun = a function to calculate the test vector from data/simulation
#'   fitf <- function(X) {
#'     kppm(X, clusters = "MatClust", statistic="K")
#'   }
#'   simf <- function(M) {
#'     simulate(M, nsim=1)[[1]]
#'   }
#'   calcf <- function(X) {
#'     rmin <- 0.3; rmax <- 10; rstep <- (rmax-rmin)/500
#'     r <- seq(0, rmax, by=rstep)
#'     L <- Lest(X, correction = "translate", r = r)[['trans']] - r
#'     L[r >= rmin & r <= rmax]
#'   }
#'   res <- GET.composite(X = saplings, nsim=nsim, fitfun = fitf, simfun=simf, calcfun=calcf,
#'                        type="area")
#'   plot(res, xlab="Index")
#'   # Note: r-values are not passed; r in the x-axis is from 1 to length of r.
#' }}
GET.composite <- function(X, X.ls = NULL,
                         nsim = 499, nsimsub = nsim,
                         simfun=NULL, fitfun=NULL, calcfun=function(X) { X },
                         testfuns=NULL, ...,
                         type = "erl",
                         alpha = 0.05, alternative = c("two.sided","less", "greater"),
                         probs = c(0.025, 0.975),
                         r_min=NULL, r_max=NULL, take_residual=FALSE,
                         save.cons.envelope = savefuns, savefuns = FALSE,
                         verbose=TRUE, MrkvickaEtal2017 = FALSE, mc.cores=1L) {
  alt <- match.arg(alternative)

  # Simulations
  #------------
  # 1) All simulations provided
  #----------------------------
  if(!is.null(X.ls)) {
    # Check dimensions of each curve_set and transform to curve_sets
    if(class(X)[1] != "list") {
      X <- list(X) # The observed curves (a list of curve_set objects)
      X.ls <- lapply(X.ls, FUN=list) # The simulated curves (a list of lists of curve_set objects)
    }
    picked_attr_ls <- lapply(X, FUN=pick_attributes, alternative=alt, type=type)
    X <- check_curve_set_dimensions(X)
    X.ls <- lapply(X.ls, FUN = check_curve_set_dimensions)
    # Check equality of dimensions over repetitions
    if(!all(sapply(X.ls, FUN=function(curve_set) { identical(curve_set[[1]]$r, y=X[[1]]$r) }))) stop("The number of argument values in the observed and simulated sets of curves differ.\n")
    if(!all(sapply(X.ls, FUN=function(curve_set) { identical(dim(curve_set[[1]]$sim_m), y=dim(X[[1]]$sim_m)) }))) stop("The number of simulations in the observed and simulated sets of curves differ.\n")
    # Checking r_min, r_max
    if(!is.null(r_min) & length(r_min) != length(X)) stop("r_min should give the minimum distances for each of the test functions.\n")
    if(!is.null(r_max) & length(r_max) != length(X)) stop("r_max should give the maximum distances for each of the test functions.\n")
    cat("Using the simulations provided in X and X.ls.\n")
  }
  # 2) Simulations if X.ls not provided
  #------------------------------------
  else { # Perform simulations
    if(verbose) cat("Performing simulations, ...\n")
    tmp <- adj.simulate(X=X, nsim=nsim, nsimsub=nsimsub,
                       simfun=simfun, fitfun=fitfun, calcfun=calcfun, testfuns=testfuns, ...,
                       verbose=verbose, mc.cores=mc.cores)
    picked_attr_ls <- lapply(tmp$X, FUN=pick_attributes, alternative=alt, type=type)
    X <- check_curve_set_dimensions(tmp$X)
    X.ls <- lapply(tmp$X.ls, FUN = check_curve_set_dimensions)
  }

  # Crop curves (if r_min or r_max given)
  #------------
  nfuns <- length(X)
  # Cropping (and tranforming to curve_sets)
  if(!is.null(r_min) | !is.null(r_max)) {
    tmpfunc <- function(i, csets) crop_curves(csets[[i]], r_min=r_min[i], r_max=r_max[i])
    X <- lapply(1:nfuns, FUN=tmpfunc, csets=X)
    for(sim in 1:length(X.ls)) X.ls[[sim]] <- lapply(1:nfuns, FUN=tmpfunc, csets=X.ls[[sim]])
  }

  # Take residual
  #--------------
  if(take_residual) {
    tmpfunc <- function(i, csets) residual(csets[[i]])
    X <- lapply(1:nfuns, FUN=tmpfunc, csets=X)
    for(sim in 1:length(X.ls)) X.ls[[sim]] <- lapply(1:nfuns, FUN=tmpfunc, csets=X.ls[[sim]])
  }

  # Individual tests
  #-----------------
  # For data
  obs_res <- adj.GET_helper(curve_sets=X, type=type, alpha=alpha, alternative=alt, ties="midrank",
                           probs=probs, MrkvickaEtal2017=MrkvickaEtal2017, save.envelope=TRUE)
  # For simulations
  loopfun <- function(rep) {
    tmp <- adj.GET_helper(curve_sets=X.ls[[rep]], type=type, alpha=alpha, alternative=alt, ties="midrank",
                         probs=probs, MrkvickaEtal2017=MrkvickaEtal2017)
    list(stat = tmp$stat, pval = tmp$pval)
  }
  mclapply_res <- mclapply(X=1:length(X.ls), FUN=loopfun, mc.cores=mc.cores)
  stats <- sapply(mclapply_res, function(x) x$stat)
  pvals <- sapply(mclapply_res, function(x) x$pval)

  # The adjusted test
  #------------------
  if(MrkvickaEtal2017 & type %in% c("st", "qdir") & nfuns > 1) { # Combined tests as in Mrkvicka et al. (2017)
    res <- attr(obs_res, "envelope_test")
    #-- The rank test at the second level
    # Calculate the critical rank / alpha
    kalpha_star <- quantile(stats, probs=alpha, type=1)
    data_and_sim_curves <- data_and_sim_curves(attr(res, "level2_curve_set")) # the second step "curves"
    nr <- ncol(data_and_sim_curves)
    Nfunc <- nrow(data_and_sim_curves)
    LB <- array(0, nr)
    UB <- array(0, nr)
    for(i in 1:nr){
      Hod <- sort(data_and_sim_curves[,i])
      LB[i]<- Hod[kalpha_star]
      UB[i]<- Hod[Nfunc-kalpha_star+1]
    }
    # -> kalpha_star, LB, UB of the (second level) rank test
    # Update res object with adjusted values
    attr(res, "level2_ge")$lo <- LB
    attr(res, "level2_ge")$hi <- UB
    attr(attr(res, "level2_ge"), "k_alpha_star") <- kalpha_star # Add kalpha_star
    # Re-calculate the new qdir/st envelopes
    envchars <- combined_scaled_MAD_bounding_curves_chars(X, type = type)
    central_curves_ls <- lapply(X, function(x) get_T_0(x))
    bounding_curves <- combined_scaled_MAD_bounding_curves(central_curves_ls=central_curves_ls, max_u=UB,
                                                           lower_f=envchars$lower_f, upper_f=envchars$upper_f)
    # Update the first level envelopes for plotting
    for(i in 1:length(res)) {
      res[[i]]$lo <- bounding_curves$lower_ls[[i]]
      res[[i]]$hi <- bounding_curves$upper_ls[[i]]
    }
  }
  else { # Otherwise, the ERL test is used at the second level of a combined test
    if(type == "rank" & nfuns == 1) {
      # Calculate the critical rank (instead of alpha) and the adjusted envelope following Myllymäki et al. (2017)
      kalpha_star <- quantile(stats, probs=alpha, type=1)
      data_and_sim_curves <- data_and_sim_curves(X[[1]]) # all the functions
      nr <- length(X[[1]]$r)
      Nfunc <- nrow(data_and_sim_curves)
      LB <- array(0, nr)
      UB <- array(0, nr)
      for(i in 1:nr){
        Hod <- sort(data_and_sim_curves[,i])
        LB[i]<- Hod[kalpha_star]
        UB[i]<- Hod[Nfunc-kalpha_star+1]
      }
      # For getting automatically an global_envelope object, first call central_region
      res <- central_region(X, type=type, coverage=1-alpha, alternative=alt, central="mean")
      # Update res object with adjusted values
      res$lo <- LB
      res$hi <- UB
      attr(res, "k_alpha_star") <- kalpha_star # Add kalpha_star
    }
    else {
      alpha_star <- quantile(pvals, probs=alpha, type=1)
      res <- global_envelope_test(X, type=type, alpha=alpha_star, alternative=alt)
      # Save additional arguments
      if(nfuns == 1) {
        attr(res, "alpha") <- alpha
        attr(res, "alpha_star") <- alpha_star
      }
      else {
        attr(attr(res, "level2_ge"), "alpha") <- alpha
        attr(attr(res, "level2_ge"), "alpha_star") <- alpha_star
      }
    }
  }

  # Update attributes
  if(nfuns == 1) {
    for(n in names(picked_attr_ls[[1]])) attr(res, n) <- picked_attr_ls[[1]][[n]]
  }
  else { # nfuns > 1
    for(n in names(picked_attr_ls[[1]]))
      for(i in 1:nfuns)
        attr(res[[i]], n) <- picked_attr_ls[[i]][[n]]
  }
  attr(res, "method") <- "Adjusted global envelope test" # Change method name
  attr(res, "call") <- match.call() # Update "call" attribute
  # Additions
  if(savefuns) {
    attr(res, "simfuns") <- X
    attr(res, "simfuns.ls") <- X.ls
  }
  if(save.cons.envelope) attr(res, "unadjusted_test") <- attr(obs_res, "envelope_test")
  attr(res, "simulated_p") <- pvals
  attr(res, "simulated_k") <- stats
  # Return
  res
}
