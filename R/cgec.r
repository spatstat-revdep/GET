#' Centred government expenditure centralization ratios
#'
#' Centred government expenditure centralization (GEC) ratios
#'
#'
#' The data includes the government expenditure centralization (GEC) ratio in percent that has been
#' centred with respect to country average in order to remove the differences in absolute values of
#' GEC.
#' The GEC ratio is the ratio of central government expenditure to the total general government expenditure.
#' Data were collected from the Eurostat (2018) database.
#' Only those European countries were included, where the data were available from 1995 to 2016 without
#' interruption. Finally, 29 countries were classified into three groups in the following way:
#' \itemize{
#' \item Group 1: Countries joining EC between 1958 and 1986 (Belgium, Denmark, France, Germany
#' (until 1990 former territory of the FRG), Greece, Ireland, Italy, Luxembourg, Netherlands, Portugal,
#' Spain, United Kingdom. These countries have long history of European integration, representing the
#' core of integration process.
#' \item Group 2: Countries joining the EU in 1995 (Austria, Sweden, Finland) and 2004 (Malta, Cyprus),
#' except CEEC (separate group), plus highly economically integrated non-EU countries, EFTA members
#' (Norway, Switzerland). Countries in this group have been, or in some case even still are standing
#' apart from the integration mainstream. Their level of economic integration is however very high.
#' \item Group 3: Central and Eastern European Countries (CEEC), having similar features in political
#' end economic history. The process of economic and political integration have been initiated by
#' political changes in 1990s. CEEC joined the EU in 2004 and 2007 (Bulgaria, Czech Republic, Estonia,
#' Hungary, Latvia, Lithuania, Poland, Romania, Slovakia, Slovenia, data for Croatia joining in 2013 are
#' incomplete, therefore not included).
#' }
#' This grouping is used in examples.
#'
#' @format A \code{curve_set} object with components \code{r} and \code{obs}
#' containing the years of observations and the curves, i.e. the observed values of centred GEC in
#' those years. Each column of \code{obs} contains the centred GEC for the years for a particular
#' country (seen as column names). The grouping is given in the attribute \code{group}.
#'
#' @usage data(cgec)
#' @references
#' Eurostat (2018). "Government revenue, expenditure and main aggregates (gov10amain)”. Retrieved from https://ec.europa.eu/eurostat/data/database(26/10/2018).
#'
#' Mrkvička, T., Hahn, U. and Myllymäki, M. A one-way ANOVA test for functional data with graphical interpretation. arXiv:1612.03608 [stat.ME] (http://arxiv.org/abs/1612.03608)
#' @keywords datasets
#' @keywords curves
#' @name cgec
#' @docType data
#' @seealso \code{\link{graph.fanova}}
#' @examples
#' data(cgec)
#' # Plot data in groups
#' subs <- function(group, ...) {
#'   cset <- cgec
#'   cset$obs <- cgec$obs[, attr(cset, "group") == group]
#'   plot(cset, ...)
#' }
#' par(mfrow=c(1,3))
#' for(i in 1:3) subs(i, main=paste("Group ", i, sep=""), ylab="Centred GEC")
#'
#' # See example analysis in ?graph.fanova
NULL