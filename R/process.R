#' normalization
#'
#' normalize data for numerical factors
#'
#' @param object Cookie object
#'
#' @export
#'
#'

normalization <- function (
  object = NULL
) {
  if(!is.null(object)) {
    types <- object@factor.type
    num.index <- which(types == "num")
    raw.data <- object@raw.data
    if(length(num.index) > 0) {
      for (index in num.index) {
        col <- raw.data[,index]
        na.index <- which(col == "NA")
        col[na.index] <- min(col)
        raw.data[,index] <- (col - min(col))/(max(col) - min(col))
        raw.data[na.index,index] <- -1
      }
    } else {
      cat("Didn't find any numerical factor, will directly copy data from raw.data slot!\n")
    }
    object@normalize.data <- raw.data
    return(object)
  } else {
    stop("Please provide Cookie object")
  }
}


#' distCalculation
#'
#' calculate distance from normalized data
#'
#' @param object Cookie object
#' @param weight weight for each factor
#'
#' @export
#'
#'

distCalculation <- function (
  object = NULL,
  weight = NULL
) {
  if(!is.null(object)) {
    types <- object@factor.type
    num.index <- which(types == "num")
    data <- object@normalize.data
    if(is.null(weight)){
      weight <- rep(1,length(types))
    } else {
      if(length(types) != length(weight)) {
        stop("Weights number should be equal to factor number!")
      }
    }

    if(length(num.index) > 0) {
      # numerical matrix
      data1 <- as.matrix(data[,num.index])
      w1 <- weight[num.index]
      for (i in 1:length(w1)) {
        data1[,i] <- data1[,i]*w1[i]
      }
      # char matrix
      data2 <- data[,-num.index]
      w2 <- weight[-num.index]

      dist.matrix1 <- hammingCodingCpp(data1)
      dist.matrix2 <- binaryCodingCpp(data2,w2)

      dist.matrix <- dist.matrix1 + dist.matrix2
    } else {
      dist.matrix <- binaryCodingCpp(data,weight)
    }

    object@dist.matrix <- dist.matrix

    return(object)
  } else {
    stop("Please provide Cookie object")
  }
}


#' binaryCoding
#'
#' calculate binary distance for char distance
#'
#' @param data data matrix
#'
#' @export
#'
#'

binaryCoding <- function(
  data = NULL
) {
  n <- dim(data)[1]
  m <- dim(data)[2]
  res <- matrix(0,n,n)
  for (i in 1:n) {
    cat("i = ", i, " \n")
    for (j in i:n) {
      #cat("j = ", j, " \n")
      vec.i <- data[i,]
      vec.j <- data[j,]

      vec.res <- rep(0,m)
      for (k in 1:m) {
        if(vec.i[k] == vec.j[k]) {
          vec.res[k] <- 0
        } else {
          vec.res[k] <- 1
        }
      }
      a <- sum(vec.res)
      res[i,j] <- a
      res[j,i] <- a
    }
  }
  return(res)
}

#' hammingCoding
#'
#' calculate hamming distance for num distance
#'
#' @param data data matrix
#'
#' @export
#'
#'

hammingCoding <- function(
  data = NULL
){
  n <- dim(data)[1]
  m <- dim(data)[2]
  res <- matrix(0,n,n)
  for (i in 1:n) {
    cat("i = ", i, " \n")
    for (j in i:n) {
      #cat("j = ", j, " \n")
      vec.i <- data[i,]
      vec.j <- data[j,]

      vec.res <- abs(vec.i - vec.j)
      a <- sum(vec.res)
      res[i,j] <- a
      res[j,i] <- a
    }
  }
  return(res)
}


#' reductionTSNE
#'
#' Run t-SNE to project samples into 2D map using pairwise distances
#'
#' @param object (For Seurat) Seurat object
#' @param assay (For Seurat) run t-SNE for which assay, choose from RNA, ADT, Joint or All
#' @param perplexity numeric; Perplexity parameter (should not be bigger than 3 * perplexity < nrow(X) - 1, see details for interpretation)
#' @param dim integer; Output dimensionality (default: 2)
#' @param seed integer; seed for reproducible results.
#' @param theta numeric; Speed/accuracy trade-off (increase for less accuracy), set to 0.0 for exact TSNE (default: 0.5)
#'
#' @importFrom Rtsne Rtsne
#'
#' @export
#'

reductionTSNE <- function(
  object,
  perplexity = 30,
  dim = 2,
  seed = 42,
  theta = 0.5
) {
  if(!is.null(object)){
    set.seed(seed = seed)

    cat("Start run t-SNE from distances...\n")

    data <- object@dist.matrix

    # run tsne with pairwise distances
    my.tsne <- Rtsne(data, perplexity = perplexity, is_distance = TRUE, dims = dim, theta = theta)

    object@reduction[['tsne']] <- createDimReductionObject(data = my.tsne$Y, method = "t-SNE")
    return(object)
  } else {
    stop("Please provide a Cookie object!")
  }
}




#' reductionUMAP
#'
#' Run UMAP to project samples into 2D space using pairwise distances
#'
#' @param object Cookie object
#' @param seed see number. default is 42
#' @param method could be "naive" or "umap-learn". If choose "umap-learn", user may need to install python package umap-learn (https://pypi.org/project/umap-learn/)
#' @param n.neighbors integer; number of nearest neighbors
#' @param n.components  integer; dimension of target (output) space
#' @param metric character or function; determines how distances between data points are computed. When using a string, available metrics are: euclidean, manhattan. Other available generalized metrics are: cosine, pearson, pearson2. Note the triangle inequality may not be satisfied by some generalized metrics, hence knn search may not be optimal. When using metric.function as a function, the signature must be function(matrix, origin, target) and should compute a distance between the origin column and the target columns
#' @param verbose logical or integer; determines whether to show progress messages
#' @param n.epochs  integer; number of iterations performed during layout optimization
#' @param min.dist  numeric; determines how close points appear in the final layout
#' @param spread numeric; used during automatic estimation of a/b parameters.
#' @param set.op.mix.ratio numeric in range [0,1]; determines who the knn-graph is used to create a fuzzy simplicial graph
#' @param local.connectivity  numeric; used during construction of fuzzy simplicial set
#' @param negative.sample.rate  integer; determines how many non-neighbor points are used per point and per iteration during layout optimization
#'
#' @importFrom umap umap umap.defaults
#'
#' @export
#'
reductionUMAP <- function(
  object,
  seed = 42,
  method = "naive",
  n.neighbors = 15,
  n.components = 2,
  metric = "manhattan",
  verbose = TRUE,
  n.epochs = 200,
  min.dist = 0.1,
  spread = 1,
  set.op.mix.ratio = 1,
  local.connectivity = 1L,
  negative.sample.rate = 5L
) {
  if(!is.null(object)){
    set.seed(seed = seed)

    my.umap.conf <- umap.defaults
    my.umap.conf$input <- "dist"
    my.umap.conf$n_neighbors <- n.neighbors
    my.umap.conf$n_components <- n.components
    my.umap.conf$metric <- metric
    my.umap.conf$verbose <- verbose
    my.umap.conf$n_epochs <- n.epochs
    my.umap.conf$min_dist <- min.dist
    my.umap.conf$spread <- spread
    my.umap.conf$set_op_mix_ratio <- set.op.mix.ratio
    my.umap.conf$local_connectivity <- local.connectivity
    my.umap.conf$negative_sample_rate <- negative.sample.rate

    cat("Start run UMAP from distances...\n")

    dist <- object@dist.matrix
    my.umap <- umap(dist,my.umap.conf,method = method)

    object@reduction[['umap']] <- createDimReductionObject(data = my.umap$layout, method = "UMAP")
    return(object)
  } else {
    stop("Please provide a Cookie object!")
  }
}


#' sampleSizeTest
#'
#' Run sample size test for current dataset
#'
#' @param object Cookie object
#' @param prime.factor The unique prime factor.
#' @param size.range Sample size range
#' @param name A name for this run. e.g. test1
#' @param fast.mode A fast version of PAM algorithm in R package "cluster".By default is FALSE. Users can set this value to 3, 4, or 5 to use FastPAM (https://stat.ethz.ch/R-manual/R-patched/library/cluster/html/pam.html)
#'
#' @importFrom cluster pam
#'
#' @export
#'

sampleSizeTest <- function(
  object = NULL,
  prime.factor = NULL,
  size.range = NULL,
  name = NULL,
  fast.mode = FALSE
) {
  if(!is.null(object)){
    if(!is.null(name)) {
      n.sample <- dim(object@normalize.data)[1]
      n.factor <- dim(object@normalize.data)[2]
      n.size <- length(size.range)
      dist.matrix <- object@dist.matrix
      data <- object@normalize.data
      type <- object@factor.type

      coverage <- matrix(data = 0, nrow = n.size, ncol = (n.factor + 1))
      coveragecc <- matrix(data = 0, nrow = n.size, ncol = (n.factor + 1))
      selection <- matrix(data = NA, nrow = n.sample, ncol = n.size)

      if(!is.null(prime.factor)) {
        # sampling from each level of prime factor
        factors <- colnames(object@normalize.data)
        if(prime.factor %in% factors) {
          subject.list <- unique(data[,prime.factor])
          i = 1
          for (n in size.range) {
            cat("test sample size = ",n,"for each subject in prime factor... \n")
            for (subject in subject.list) {
              index <- which(data[,prime.factor] == subject)
              if(length(index) > n) {
                sub.dist.matrix <- dist.matrix[index,index]
                res <- pam(x = sub.dist.matrix, k = n, diss = TRUE, pamonce = fast.mode)

                orig.index <- index[res[["id.med"]]]
                selection[orig.index,i] <- "Selected"
              } else {
                cat("Number of samples in current subject = ",subject," is less than n = ",n,", will select all samples in this subject!\n")
                selection[index,i] <- "Selected"
              }
            }

            a <- selection[,i]
            index.a <- which(!is.na(a))
            subset <- data[index.a,]

            coverage[i,1] = n
            for (j in 1:n.factor) {
              if(type[j] != "num") {
                coverage[i,(j+1)] <- length(unique(subset[,j]))/length(unique(data[,j]))
              } else {
                coverage[i,(j+1)] <- length(unique(floor(subset[,j]*10)))/length(unique(floor(data[,j]*10)))
              }
            }
            i <- i + 1
          }
        } else {
          stop("The prime factor you provided is not exist! Please check your input!")
        }
      } else {
        # sampling from the entire population
        i = 1
        for (n in size.range) {
          cat("test sample size = ",n," for the entire population... \n")
          res <- pam(x = dist.matrix, k = n, diss = TRUE, pamonce = fast.mode)
          selection[res[["id.med"]],i] <- "Selected"

          subset <- data[res[["id.med"]],]

          coverage[i,1] = n
          for (j in 1:n.factor) {
            if(type[j] != "num") {
              coverage[i,(j+1)] <- length(unique(subset[,j]))/length(unique(data[,j]))
            } else {
              coverage[i,(j+1)] <- length(unique(floor(subset[,j]*10)))/length(unique(floor(data[,j]*10)))
            }
          }
          i <- i + 1
        }
      }
      coverage <- as.data.frame(coverage)
      rownames(coverage) <- size.range
      colnames(coverage) <- c("Size",colnames(data))

      selection <- as.data.frame(selection)
      rownames(selection) <- rownames(data)
      colnames(selection) <- size.range

      if(is.null(prime.factor)){
        prime.factor <- "NA"
      }
      object@sample.size.test[[name]] <- createSampleSizeTestObject(prime.factor = prime.factor,coverage = coverage,selection = selection)
      return(object)
    } else {
      stop("Please provide a name for this test (e.g. test1)!")
    }
  } else {
    stop("Please provide a Cookie object!")
  }
}



#' sampling
#'
#' Sampling from current dataset
#'
#' @param object Cookie object
#' @param prime.factor The unique prime factor.
#' @param important.factor the important factors
#' @param sample.size Sample size
#' @param name A name for this run. e.g. test1
#' @param fast.mode A fast version of PAM algorithm in R package "cluster".By default is FALSE. Users can set this value to 3, 4, or 5 to use FastPAM (https://stat.ethz.ch/R-manual/R-patched/library/cluster/html/pam.html)
#'
#' @importFrom cluster pam
#' @importFrom Rfast rowMins
#'
#' @export
#'

sampling <- function(
  object = NULL,
  prime.factor = NULL,
  important.factor = NULL,
  sample.size = NULL,
  name = NULL,
  fast.mode = FALSE
) {
  if(!is.null(object)){
    if(!is.null(name)) {
      n.sample <- dim(object@normalize.data)[1]
      n.factor <- dim(object@normalize.data)[2]
      dist.matrix <- object@dist.matrix
      data <- object@normalize.data
      type <- object@factor.type

      coverage <- matrix(data = 0, nrow = 1, ncol = (n.factor + 1))
      coveragecc <- matrix(data = 0, nrow = 1, ncol = (n.factor + 1))
      selection <- matrix(data = NA, nrow = n.sample, ncol = 1)
      # step 1
      if(!is.null(prime.factor)) {
        # sampling from each level of prime factor
        factors <- colnames(object@normalize.data)
        if(prime.factor %in% factors) {
          subject.list <- unique(data[,prime.factor])

          for (subject in subject.list) {
            index <- which(data[,prime.factor] == subject)
            if(length(index) > sample.size) {
              sub.dist.matrix <- dist.matrix[index,index]
              res <- pam(x = sub.dist.matrix, k = sample.size, diss = TRUE, pamonce = fast.mode)

              orig.index <- index[res[["id.med"]]]
              selection[orig.index,1] <- "Selected"
            } else {
              cat("Number of samples in current subject = ",subject," is less than n = ",sample.size,", will select all samples in this subject!\n")
              selection[index,1] <- "Selected"
            }
          }
        } else {
          stop("The prime factor you provided is not exist! Please check your input!")
        }
      } else {
        # sampling from the entire population
        res <- pam(x = dist.matrix, k = sample.size, diss = TRUE, pamonce = fast.mode)
        selection[res[["id.med"]],1] <- "Selected"
      }

      # step 2
      index.a <- which(!is.na(selection))
      subset <- data[index.a,]
      if(!is.null(important.factor)) {
        for (important in important.factor) {
          original.important <- unique(data[,important])
          cur.important <- unique(subset[,important])
          diff <- setdiff(original.important, cur.important)

          if(length(diff) > 0) {
            for (var in diff) {
              ### select sample with minimum average distance
              # candidate.index <- which(data[,important] == var)
              # a <- dist.matrix[candidate.index, index.a]
              # a <- rowSums(a)
              # sel.index <- which(a == min(a))
              # sel.index <- candidate.index[sel.index]

              # select sample with maximum local distance
              candidate.index <- which(data[,important] == var)
              a <- dist.matrix[candidate.index, index.a]
              rowmins <- rowMins(a, value = TRUE)
              sel.index <- which(rowmins == max(rowmins))[1]
              sel.index <- candidate.index[sel.index]

              # set selected marker
              selection[sel.index] <- "Selected"
            }
          }
        }
      }

      # summary
      a <- selection[,1]
      index.a <- which(!is.na(a))
      subset <- data[index.a,]
      coverage[1,1] <- sample.size
      for (j in 1:n.factor) {
        if(type[j] != "num") {
          coverage[1,(j+1)] <- length(unique(subset[,j]))/length(unique(data[,j]))
        } else {
          coverage[1,(j+1)] <- length(unique(floor(subset[,j]*10)))/length(unique(floor(data[,j]*10)))
        }
      }

      coveragecc[1,1] = sample.size
      for (j in 1:n.factor) {
        if(type[j] != "num") {
          population <- as.data.frame(table(data[,j]))
          population$Var1 <- as.character(population$Var1)
          samples <- as.data.frame(table(subset[,j]))
          samples$Var1 <- as.character(samples$Var1)

          tmp <- rep(0,dim(population)[1])
          for (k in 1:dim(samples)[1]) {
            index <- which(population$Var1 == samples$Var1[k])
            tmp[index] <- samples$Freq[k]
          }
          population$FreqSel <- tmp

          if(is.na(cor(population$FreqSel, population$Freq))) {
            coveragecc[1,(j+1)] <- 0
          } else {
            coveragecc[1,(j+1)] <- cor(population$FreqSel, population$Freq)
          }
        } else {
          a <- floor(subset[,j]*10)
          b <- floor(data[,j]*10)

          population <- as.data.frame(table(b))
          population$b <- as.character(population$b)
          samples <- as.data.frame(table(a))
          samples$a <- as.character(samples$a)

          tmp <- rep(0,dim(population)[1])
          for (k in 1:dim(samples)[1]) {
            index <- which(population$b == samples$a[k])
            tmp[index] <- samples$Freq[k]
          }
          population$FreqSel <- tmp

          if(is.na(cor(population$FreqSel, population$Freq))) {
            coveragecc[1,(j+1)] <- 0
          } else {
            coveragecc[1,(j+1)] <- cor(population$FreqSel, population$Freq)
          }
        }
      }

      coverage <- as.data.frame(coverage)
      rownames(coverage) <- sample.size
      colnames(coverage) <- c("Size",colnames(data))

      coveragecc <- as.data.frame(coveragecc)
      rownames(coveragecc) <- sample.size
      colnames(coveragecc) <- c("Size",colnames(data))

      selection <- as.data.frame(selection)
      rownames(selection) <- rownames(data)
      colnames(selection) <- sample.size
      if(is.null(prime.factor)){
        prime.factor <- "NA"
      }
      if(is.null(important.factor)){
        important.factor <- "NA"
      }
      object@samplings[[name]] <- createSamplingObject(prime.factor = prime.factor,important.factor = important.factor, coverage = coverage, sampling = selection, size = sample.size, coveragecc = coveragecc)
      return(object)
    } else {
      stop("Please provide a name for this test (e.g. test1)!")
    }
  } else {
    stop("Please provide a Cookie object!")
  }
}

#' getSampling
#'
#' Get selected samples from a sampling
#'
#' @param object Cookie object
#' @param name Name for a specific sampling run. e.g. run1
#'
#' @importFrom cluster pam
#'
#' @export
#'

getSampling <- function(
  object = NULL,
  name = NULL
) {
  if(!is.null(object)){
    if(!is.null(object@samplings[[name]])){
      data <- object@raw.data
      sel <- object@samplings[[name]]@sampling
      sel.index <- !is.na(sel[,1])
      data <- data[sel.index,]
      return(data)
    } else {
      stop("The factor name you provided does not exist!")
    }
  } else {
    stop("Please provide a Cookie object!")
  }
}


#' simpleRandomSampling
#'
#' Simple Random Sampling from current dataset
#'
#' @param object Cookie object
#' @param sample.size Sample size
#' @param name A name for this run. e.g. test1
#'
#'
#' @export
#'

simpleRandomSampling <- function(
  object = NULL,
  sample.size = NULL,
  name = NULL
) {
  if(!is.null(object)){
    if(!is.null(name)) {
      n.sample <- dim(object@normalize.data)[1]
      n.factor <- dim(object@normalize.data)[2]
      dist.matrix <- object@dist.matrix
      data <- object@normalize.data
      type <- object@factor.type

      coverage <- matrix(data = 0, nrow = 1, ncol = (n.factor + 1))
      coveragecc <- matrix(data = 0, nrow = 1, ncol = (n.factor + 1))
      selection <- matrix(data = NA, nrow = n.sample, ncol = 1)

      index <- sample(1:n.sample,size = sample.size, replace = FALSE)
      selection[index,1] <- "Selected"

      # summary
      a <- selection[,1]
      index.a <- which(!is.na(a))
      subset <- data[index.a,]
      coverage[1,1] <- sample.size
      for (j in 1:n.factor) {
        if(type[j] != "num") {
          coverage[1,(j+1)] <- length(unique(subset[,j]))/length(unique(data[,j]))
        } else {
          coverage[1,(j+1)] <- length(unique(floor(subset[,j]*10)))/length(unique(floor(data[,j]*10)))
        }
      }

      coveragecc[1,1] = sample.size
      for (j in 1:n.factor) {
        if(type[j] != "num") {
          population <- as.data.frame(table(data[,j]))
          population$Var1 <- as.character(population$Var1)
          samples <- as.data.frame(table(subset[,j]))
          samples$Var1 <- as.character(samples$Var1)

          tmp <- rep(0,dim(population)[1])
          for (k in 1:dim(samples)[1]) {
            index <- which(population$Var1 == samples$Var1[k])
            tmp[index] <- samples$Freq[k]
          }
          population$FreqSel <- tmp

          if(is.na(cor(population$FreqSel, population$Freq))) {
            coveragecc[1,(j+1)] <- 0
          } else {
            coveragecc[1,(j+1)] <- cor(population$FreqSel, population$Freq)
          }
        } else {
          a <- floor(subset[,j]*10)
          b <- floor(data[,j]*10)

          population <- as.data.frame(table(b))
          samples <- as.data.frame(table(a))

          tmp <- rep(0,dim(population)[1])
          for (k in 1:dim(samples)[1]) {
            index <- which(population$Var1 == samples$Var1[k])
            tmp[index] <- samples$Freq[k]
          }
          population$FreqSel <- tmp

          if(is.na(cor(population$FreqSel, population$Freq))) {
            coveragecc[1,(j+1)] <- 0
          } else {
            coveragecc[1,(j+1)] <- cor(population$FreqSel, population$Freq)
          }
        }
      }

      coverage <- as.data.frame(coverage)
      rownames(coverage) <- sample.size
      colnames(coverage) <- c("Size",colnames(data))

      coveragecc <- as.data.frame(coveragecc)
      rownames(coveragecc) <- sample.size
      colnames(coveragecc) <- c("Size",colnames(data))

      selection <- as.data.frame(selection)
      rownames(selection) <- rownames(data)
      colnames(selection) <- sample.size

      object@samplings[[name]] <- createSamplingObject(prime.factor = "NA",important.factor = "NA", coverage = coverage, sampling = selection, size = sample.size, coveragecc = coveragecc)
      return(object)
    } else {
      stop("Please provide a name for this test (e.g. test1)!")
    }
  } else {
    stop("Please provide a Cookie object!")
  }
}


#' stratifiedSampling
#'
#' Stratified Sampling from current dataset
#'
#' @param object Cookie object
#' @param sample.size Sample size
#' @param prime.factor The unique prime factor.
#' @param name A name for this run. e.g. test1
#'
#'
#' @export
#'

stratifiedSampling <- function(
  object = NULL,
  prime.factor = NULL,
  sample.size = NULL,
  name = NULL
) {
  if(!is.null(object)){
    if(!is.null(name)) {
      n.sample <- dim(object@normalize.data)[1]
      n.factor <- dim(object@normalize.data)[2]
      dist.matrix <- object@dist.matrix
      data <- object@normalize.data
      type <- object@factor.type

      coverage <- matrix(data = 0, nrow = 1, ncol = (n.factor + 1))
      coveragecc <- matrix(data = 0, nrow = 1, ncol = (n.factor + 1))
      selection <- matrix(data = NA, nrow = n.sample, ncol = 1)

      # sampling from each level of prime factor
      factors <- colnames(object@normalize.data)
      if(prime.factor %in% factors) {
        subject.list <- unique(data[,prime.factor])

        for (subject in subject.list) {
          index <- which(data[,prime.factor] == subject)
          if(length(index) > sample.size) {
            sub.index <- sample(index,size = sample.size, replace = FALSE)
            selection[sub.index,1] <- "Selected"
          } else {
            cat("Number of samples in current subject = ",subject," is less than n = ",sample.size,", will select all samples in this subject!\n")
            selection[index,1] <- "Selected"
          }
        }
      } else {
        stop("The prime factor you provided is not exist! Please check your input!")
      }

      # summary
      a <- selection[,1]
      index.a <- which(!is.na(a))
      subset <- data[index.a,]
      coverage[1,1] <- sample.size
      for (j in 1:n.factor) {
        if(type[j] != "num") {
          coverage[1,(j+1)] <- length(unique(subset[,j]))/length(unique(data[,j]))
        } else {
          coverage[1,(j+1)] <- length(unique(floor(subset[,j]*10)))/length(unique(floor(data[,j]*10)))
        }
      }

      coveragecc[1,1] = sample.size
      for (j in 1:n.factor) {
        if(type[j] != "num") {
          population <- as.data.frame(table(data[,j]))
          population$Var1 <- as.character(population$Var1)
          samples <- as.data.frame(table(subset[,j]))
          samples$Var1 <- as.character(samples$Var1)

          tmp <- rep(0,dim(population)[1])
          for (k in 1:dim(samples)[1]) {
            index <- which(population$Var1 == samples$Var1[k])
            tmp[index] <- samples$Freq[k]
          }
          population$FreqSel <- tmp

          if(is.na(cor(population$FreqSel, population$Freq))) {
            coveragecc[1,(j+1)] <- 0
          } else {
            coveragecc[1,(j+1)] <- cor(population$FreqSel, population$Freq)
          }
        } else {
          a <- floor(subset[,j]*10)
          b <- floor(data[,j]*10)

          population <- as.data.frame(table(b))
          samples <- as.data.frame(table(a))

          tmp <- rep(0,dim(population)[1])
          for (k in 1:dim(samples)[1]) {
            index <- which(population$Var1 == samples$Var1[k])
            tmp[index] <- samples$Freq[k]
          }
          population$FreqSel <- tmp

          if(is.na(cor(population$FreqSel, population$Freq))) {
            coveragecc[1,(j+1)] <- 0
          } else {
            coveragecc[1,(j+1)] <- cor(population$FreqSel, population$Freq)
          }
        }
      }

      coverage <- as.data.frame(coverage)
      rownames(coverage) <- sample.size
      colnames(coverage) <- c("Size",colnames(data))

      coveragecc <- as.data.frame(coveragecc)
      rownames(coveragecc) <- sample.size
      colnames(coveragecc) <- c("Size",colnames(data))

      selection <- as.data.frame(selection)
      rownames(selection) <- rownames(data)
      colnames(selection) <- sample.size

      object@samplings[[name]] <- createSamplingObject(prime.factor = prime.factor,important.factor = "NA", coverage = coverage, sampling = selection, size = sample.size, coveragecc = coveragecc)
      return(object)
    } else {
      stop("Please provide a name for this test (e.g. test1)!")
    }
  } else {
    stop("Please provide a Cookie object!")
  }
}
