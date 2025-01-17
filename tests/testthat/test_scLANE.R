# load data & prepare for testing
load(system.file("testdata/sim_test_data.RData", package = "scLANE"))
sim_data_seu <- Seurat::as.Seurat(sim_data)
cell_offset <- createCellOffset(sim_data)
cell_offset_seu <- createCellOffset(sim_data_seu)
genes_to_test <- c(rownames(sim_data)[SummarizedExperiment::rowData(sim_data)$geneStatus_overall == "Dynamic"][1:10],
                   rownames(sim_data)[SummarizedExperiment::rowData(sim_data)$geneStatus_overall == "NotDynamic"][1:10])
counts_test <- t(as.matrix(SingleCellExperiment::counts(sim_data)[genes_to_test, ]))
pt_test <- data.frame(PT = sim_data$cell_time_normed)

# test internal functions used in model fitting
max_span_res <- max_span(X_red = pt_test[, 1], q = 1)
min_span_res <- min_span(X_red = pt_test[, 1], q = 1)
Y_exp <- sim_data@assays@data$counts[genes_to_test[1], ]
stat_out_res <- stat_out(Y = Y_exp,
                         B1 = matrix(rnorm(ncol(sim_data)), nrow = ncol(sim_data), ncol = 1),
                         TSS = sum((Y_exp - mean(Y_exp))^2),
                         GCV.null = sum((Y_exp - mean(Y_exp))^2) / (ncol(sim_data) * (1 - (1 / ncol(sim_data)))^2))
null_stat_glm <- stat_out_score_glm_null(Y = Y_exp,
                                         B_null = rep(1, ncol(sim_data)))
null_stat_gee <- stat_out_score_gee_null(Y = Y_exp,
                                         B_null = matrix(1, ncol = 1, nrow = ncol(sim_data)),
                                         id.vec = sim_data$subject,
                                         cor.structure = "ar1",
                                         theta.hat = 1)

# generate scLANE results w/ all three model architectures
withr::with_output_sink(tempfile(), {
  # run GLM, GEE, & GLMM tests
  glm_gene_stats <- testDynamic(sim_data,
                                pt = pt_test,
                                genes = genes_to_test,
                                n.potential.basis.fns = 5,
                                size.factor.offset = cell_offset,
                                n.cores = 2,
                                track.time = TRUE)
  gee_gene_stats <- testDynamic(sim_data,
                                pt = pt_test,
                                genes = genes_to_test,
                                n.potential.basis.fns = 5,
                                size.factor.offset = cell_offset,
                                is.gee = TRUE,
                                cor.structure = "ar1",
                                id.vec = sim_data$subject,
                                n.cores = 2,
                                track.time = FALSE)
  glmm_gene_stats <- testDynamic(sim_data,
                                 pt = pt_test,
                                 genes = genes_to_test,
                                 size.factor.offset = cell_offset,
                                 n.potential.basis.fns = 3,
                                 is.glmm = TRUE,
                                 glmm.adaptive = TRUE,
                                 id.vec = sim_data$subject,
                                 n.cores = 2,
                                 track.time = TRUE)
  # get results tables overall
  glm_test_results <- getResultsDE(glm_gene_stats)
  gee_test_results <- getResultsDE(gee_gene_stats)
  glmm_test_results <- getResultsDE(glmm_gene_stats)
  # get results tables by interval
  glm_slope_test <- testSlope(glm_gene_stats)
  gee_slope_test <- testSlope(gee_gene_stats)
  glmm_slope_test <- testSlope(glmm_gene_stats)
  # run NB GAMs of varying structure
  gam_mod_bs <- nbGAM(expr = counts_test[, 1],
                      pt = pt_test,
                      Y.offset = cell_offset)
  gam_mod_ps <- nbGAM(expr = counts_test[, 1],
                      pt = pt_test,
                      Y.offset = cell_offset,
                      penalize.spline = TRUE)
  gam_mod_ps_mix <- nbGAM(expr = counts_test[, 1],
                          pt = pt_test,
                          Y.offset = cell_offset,
                          id.vec = sim_data$subject,
                          penalize.spline = TRUE)
  # run GLM model -- no offset
  marge_mod <- marge2(X_pred = pt_test,
                      Y = counts_test[, 3],
                      M = 5,
                      return.basis = TRUE,
                      return.GCV = TRUE,
                      return.WIC = TRUE)
  marge_mod_stripped <- stripGLM(marge_mod$final_mod)
  # run GLM model -- with offset
  marge_mod_offset <- marge2(X_pred = pt_test,
                             Y = counts_test[, 3],
                             Y.offset = cell_offset,
                             M = 5,
                             return.basis = TRUE,
                             return.GCV = TRUE,
                             return.WIC = TRUE)
  # run GEE model -- no offset
  marge_mod_GEE <- marge2(X_pred = pt_test,
                          Y = counts_test[, 3],
                          M = 5,
                          is.gee = TRUE,
                          id.vec = sim_data$subject,
                          cor.structure = "ar1",
                          return.basis = TRUE,
                          return.GCV = TRUE,
                          return.WIC = TRUE)
  # run GEE model -- with offset
  marge_mod_GEE_offset <- marge2(X_pred = pt_test,
                                 Y = counts_test[, 3],
                                 Y.offset = cell_offset,
                                 M = 5,
                                 is.gee = TRUE,
                                 id.vec = sim_data$subject,
                                 cor.structure = "ar1",
                                 return.basis = TRUE,
                                 return.GCV = TRUE,
                                 return.WIC = TRUE)
  # run GLMM model -- no offset
  glmm_mod <- fitGLMM(X_pred = pt_test,
                      Y = counts_test[, 3],
                      id.vec = sim_data$subject,
                      adaptive = TRUE,
                      M.glm = 3,
                      return.basis = TRUE,
                      return.GCV = TRUE)
  # run GLMM model -- with offset
  glmm_mod_offset <- fitGLMM(X_pred = pt_test,
                             Y = counts_test[, 3],
                             Y.offset = cell_offset,
                             id.vec = sim_data$subject,
                             adaptive = TRUE,
                             M.glm = 3,
                             return.basis = TRUE,
                             return.GCV = TRUE)
  # generate plots
  plot_glm <- plotModels(test.dyn.res = glm_gene_stats,
                         size.factor.offset = cell_offset,
                         gene = "ABR",
                         pt = pt_test,
                         expr.mat = sim_data)
  plot_gee <- plotModels(test.dyn.res = gee_gene_stats,
                         gene = "ABR",
                         pt = pt_test,
                         expr.mat = sim_data,
                         size.factor.offset = cell_offset,
                         is.gee = TRUE,
                         id.vec = sim_data$subject,
                         cor.structure = "ar1")
  plot_glmm <- plotModels(test.dyn.res = glmm_gene_stats,
                          size.factor.offset = cell_offset,
                          gene = "ABR",
                          pt = pt_test,
                          expr.mat = sim_data,
                          is.glmm = TRUE,
                          id.vec = sim_data$subject)
  # downstream analysis
  set.seed(312)
  gene_clusters_leiden <- clusterGenes(test.dyn.res = glm_gene_stats,
                                       pt = pt_test,
                                       size.factor.offset = cell_offset,
                                       clust.algo = "leiden")
  gene_clusters_kmeans <- clusterGenes(test.dyn.res = glm_gene_stats,
                                       pt = pt_test,
                                       size.factor.offset = cell_offset,
                                       clust.algo = "kmeans")
  gene_clusters_hclust <- clusterGenes(test.dyn.res = glm_gene_stats,
                                       pt = pt_test,
                                       size.factor.offset = cell_offset,
                                       clust.algo = "hclust")
  gene_clust_table <- plotClusteredGenes(glm_gene_stats,
                                         gene.clusters = gene_clusters_leiden,
                                         size.factor.offset = cell_offset,
                                         pt = pt_test,
                                         n.cores = 2)
  smoothed_counts <- smoothedCountsMatrix(test.dyn.res = glm_gene_stats,
                                          pt = pt_test,
                                          size.factor.offset = cell_offset,
                                          parallel.exec = TRUE,
                                          n.cores = 2)
  gene_embedding <- embedGenes(smoothed.counts = smoothed_counts$Lineage_A,
                               pc.embed = 5,
                               pcs.return = 2,
                               k.param = 5,
                               random.seed = 312)
  sorted_genes <- sortGenesHeatmap(heatmap.mat = smoothed_counts$Lineage_A,
                                   pt.vec = pt_test$PT)
  fitted_values_table <- getFittedValues(test.dyn.res = glm_gene_stats,
                                         genes = names(glm_gene_stats),
                                         pt = pt_test,
                                         size.factor.offset = cell_offset,
                                         expr.mat = sim_data,
                                         cell.meta.data = as.data.frame(SummarizedExperiment::colData(sim_data)),
                                         id.vec = sim_data$subject)
  gsea_res <- enrichDynamicGenes(glm_test_results, species = "hsapiens")
  coef_summary_glm <- summarizeModel(marge_mod_offset, pt = pt_test)
  coef_summary_gee <- summarizeModel(marge_mod_GEE_offset, pt = pt_test)
})

# run tests
test_that("internal marge functions", {
  expect_type(min_span_res, "double")
  expect_type(max_span_res, "double")
  expect_type(stat_out_res, "list")
  expect_type(null_stat_glm, "list")
  expect_type(null_stat_gee, "list")
  expect_length(stat_out_res, 4)
  expect_length(null_stat_glm, 5)
  expect_length(null_stat_gee, 8)
})

test_that("createCellOffset() output", {
  expect_type(cell_offset, "double")
  expect_type(cell_offset_seu, "double")
  expect_length(cell_offset, 300)
  expect_length(cell_offset_seu, 300)
  expect_false(any(is.na(cell_offset)))
  expect_false(any(is.na(cell_offset_seu)))
})

test_that("testDynamic() output", {
  expect_s3_class(glm_gene_stats, "scLANE")
  expect_s3_class(gee_gene_stats, "scLANE")
  expect_s3_class(glmm_gene_stats, "scLANE")
  expect_length(glm_gene_stats, 20)
  expect_length(gee_gene_stats, 20)
  expect_length(glmm_gene_stats, 20)
  expect_s3_class(glm_gene_stats$ABCF1$Lineage_A$MARGE_Summary, "data.frame")
  expect_s3_class(gee_gene_stats$ABCF1$Lineage_A$MARGE_Summary, "data.frame")
  expect_s3_class(glmm_gene_stats$ABCF1$Lineage_A$MARGE_Summary, "data.frame")
  expect_gt(nrow(glm_gene_stats$ABCF1$Lineage_A$MARGE_Summary), 0)
  expect_gt(nrow(gee_gene_stats$ABCF1$Lineage_A$MARGE_Summary), 0)
  expect_gt(nrow(glmm_gene_stats$ABCF1$Lineage_A$MARGE_Summary), 0)
  expect_gt(sum(purrr::map_lgl(glm_gene_stats, \(x) x$Lineage_A$Model_Status == "MARGE model OK, null model OK")), 0)
  expect_gt(sum(purrr::map_lgl(gee_gene_stats, \(x) x$Lineage_A$Model_Status == "MARGE model OK, null model OK")), 0)
  expect_gt(sum(purrr::map_lgl(glmm_gene_stats, \(x) x$Lineage_A$Model_Status == "MARGE model OK, null model OK")), 0)
})

test_that("getResultsDE() output", {
  expect_s3_class(glm_test_results, "data.frame")
  expect_s3_class(gee_test_results, "data.frame")
  expect_s3_class(glmm_test_results, "data.frame")
  expect_gt(nrow(glm_test_results), 0)
  expect_gt(nrow(gee_test_results), 0)
  expect_gt(nrow(glmm_test_results), 0)
  expect_gt(sum(glm_test_results$Gene_Dynamic_Overall), 0)
  expect_gt(sum(gee_test_results$Gene_Dynamic_Overall), 0)
  expect_gt(sum(glmm_test_results$Gene_Dynamic_Overall), 0)
})

test_that("testSlope() output", {
  expect_s3_class(glm_slope_test, "data.frame")
  expect_s3_class(gee_slope_test, "data.frame")
  expect_s3_class(glmm_slope_test, "data.frame")
  expect_gt(nrow(glm_slope_test), 0)
  expect_gt(nrow(gee_slope_test), 0)
  expect_gt(nrow(glmm_slope_test), 0)
  expect_gt(sum(glm_slope_test$P_Val_Adj < 0.01, na.rm = TRUE), 0)
  expect_gt(sum(gee_slope_test$P_Val_Adj < 0.01, na.rm = TRUE), 0)
  expect_gt(sum(glmm_slope_test$P_Val_Adj < 0.01, na.rm = TRUE), 0)
})

test_that("nbGAM() output", {
  expect_s3_class(gam_mod_bs, "gamlss")
  expect_s3_class(gam_mod_ps, "gamlss")
  expect_s3_class(gam_mod_ps_mix, "gamlss")
  expect_true(gam_mod_bs$converged)
  expect_true(gam_mod_ps$converged)
  expect_true(gam_mod_ps_mix$converged)
})

test_that("marge2() output -- GLM backend", {
  expect_s3_class(marge_mod, "marge")
  expect_s3_class(marge_mod_offset, "marge")
  expect_s3_class(marge_mod$final_mod, "negbin")
  expect_s3_class(marge_mod_offset$final_mod, "negbin")
  expect_s3_class(marge_mod_stripped, "negbin")
  expect_equal(marge_mod$model_type, "GLM")
  expect_equal(marge_mod_offset$model_type, "GLM")
  expect_true(marge_mod$final_mod$converged)
  expect_true(marge_mod_offset$final_mod$converged)
})

test_that("marge2() output -- GEE backend", {
  expect_s3_class(marge_mod_GEE, "marge")
  expect_s3_class(marge_mod_GEE_offset, "marge")
  expect_s3_class(marge_mod_GEE$final_mod, "geem")
  expect_s3_class(marge_mod_GEE_offset$final_mod, "geem")
  expect_equal(marge_mod_GEE$model_type, "GEE")
  expect_equal(marge_mod_GEE_offset$model_type, "GEE")
  expect_true(marge_mod_GEE$final_mod$converged)
  expect_true(marge_mod_GEE_offset$final_mod$converged)
})

test_that("fitGLMM() output", {
  expect_s3_class(glmm_mod$final_mod, "glmmTMB")
  expect_s3_class(glmm_mod_offset$final_mod, "glmmTMB")
  expect_equal(nrow(coef(glmm_mod$final_mod)$cond$subject), 2)
  expect_equal(nrow(coef(glmm_mod_offset$final_mod)$cond$subject), 2)
  expect_false(glmm_mod$final_mod$modelInfo$REML)
  expect_false(glmm_mod_offset$final_mod$modelInfo$REML)
  expect_length(fitted(glmm_mod$final_mod), 300)
  expect_length(fitted(glmm_mod_offset$final_mod), 300)
  expect_equal(glmm_mod$model_type, "GLMM")
  expect_equal(glmm_mod_offset$model_type, "GLMM")
})

test_that("plotModels() output", {
  expect_s3_class(plot_glm, "ggplot")
  expect_s3_class(plot_gee, "ggplot")
  expect_s3_class(plot_glmm, "ggplot")
  expect_equal(ncol(plot_glm$data), 12)
  expect_equal(ncol(plot_gee$data), 12)
  expect_equal(ncol(plot_glmm$data), 12)
})

test_that("clusterGenes() output", {
  expect_s3_class(gene_clusters_leiden, "data.frame")
  expect_s3_class(gene_clusters_kmeans, "data.frame")
  expect_s3_class(gene_clusters_hclust, "data.frame")
  expect_equal(ncol(gene_clusters_leiden), 3)
  expect_equal(ncol(gene_clusters_kmeans), 3)
  expect_equal(ncol(gene_clusters_hclust), 3)
})

test_that("plotClusteredGenes() output", {
  expect_s3_class(gene_clust_table, "data.frame")
  expect_equal(ncol(gene_clust_table), 7)
})

test_that("smoothedCountsMatrix() output", {
  expect_type(smoothed_counts, "list")
  expect_length(smoothed_counts, 1)
  expect_type(smoothed_counts$Lineage_A, "double")
})

test_that("embedGenes() output", {
  expect_s3_class(gene_embedding, "data.frame")
  expect_equal(ncol(gene_embedding), 6)
})

test_that("sortGenesHeatmap() output", {
  expect_type(sorted_genes, "character")
  expect_length(sorted_genes, ncol(smoothed_counts$Lineage_A))
})

test_that("getFittedValues() output", {
  expect_s3_class(fitted_values_table, "data.frame")
  expect_equal(ncol(fitted_values_table), 25)
})

test_that("enrichDynamicGenes() output", {
  expect_type(gsea_res, "list")
  expect_length(gsea_res, 2)
  expect_s3_class(gsea_res$result, "data.frame")
})

test_that("summarizeModels() output", {
  expect_type(coef_summary_glm, "list")
  expect_type(coef_summary_gee, "list")
  expect_length(coef_summary_glm, 3)
  expect_length(coef_summary_gee, 3)
  expect_type(coef_summary_glm$Slope.Segment, "double")
  expect_type(coef_summary_gee$Slope.Segment, "double")
})
