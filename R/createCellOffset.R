#' Create an offset vector before modeling
#'
#' @name createCellOffset
#' @author Jack Leary
#' @description Creates a vector of per-cell size factors to be used as input to \code{\link{testDynamic}} as a model offset given a variety of inputs.
#' @param expr.mat Either a matrix of raw integer counts (cells as columns), a \code{Seurat} object, or a \code{SingleCellExperiment} object. Defaults to NULL.
#' @param scale.factor The scaling factor use to multiply the sequencing depth factor for each cell. The default value is 1e4, which returns counts-per-10k.
#' @return A named numeric vector containing the computed size factor for each cell.
#' @seealso \code{\link{testDynamic}}
#' @seealso \code{\link{marge2}}
#' @seealso \code{\link[Seurat]{LogNormalize}}
#' @seealso \code{\link[scuttle]{computeLibraryFactors}}
#' @export
#' @examples
#' \dontrun{
#' createCellOffset(expr.mat = counts(sce_obj))
#' createCellOffset(expr.mat = seu_obj, scale.factor = 1e5)
#' }

createCellOffset <- function(expr.mat = NULL, scale.factor = 1e4) {
  # check inputs
  if (is.null(expr.mat)) { stop("Please provide expr.mat to createCellOffset().") }
  if (inherits(expr.mat, "SingleCellExperiment")) {
    expr.mat <- as.matrix(BiocGenerics::counts(expr.mat))
  } else if (inherits(expr.mat, "Seurat")) {
    expr.mat <- as.matrix(Seurat::GetAssayData(expr.mat,
                                               slot = "counts",
                                               assay = Seurat::DefaultAssay(expr.mat)))
  } else if (inherits(expr.mat, "dgCMatrix")) {
    expr.mat <- as.matrix(expr.mat)
  }
  if (!(inherits(expr.mat, "matrix") || inherits(expr.mat, "array"))) { stop("Input expr.mat must be coerceable to a matrix of integer counts.") }
  # compute per-cell size factors
  cell_names <- colnames(expr.mat)
  seq_depths <- colSums(expr.mat)
  lib_size_factors <- scale.factor / seq_depths
  names(lib_size_factors) <- cell_names
  return(lib_size_factors)
}
