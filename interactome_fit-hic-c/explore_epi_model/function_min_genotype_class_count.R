############### SYNOPSIS ###################
# CLASS: function
# Name: function_min_genotype_class_count.R
# PURPOSE: subset data based on genotype class count criteria


############################################
options(echo=TRUE)



min_genotype_class_count <- function(idx, df.input) {
  ################## DESCRIPTION ################## 
  ### Input
  # df.input: a data frame with columns "probename", "snp1", "snp2". Other columns are allowed.
  
  ### Output
  # df.output:  a data frame IDENTICAL TO df.input, annotated with "min_genotype_class_count_threshold"
  
  ### FOR DEBUGGING ##
  #i <- 2
  #i <- 71267
  #idx <- 1:1000
  #df.input <- df.fastEpistasis.results
  
  ################## DEPENDENCIES ################## 
  library(foreach)
  library(doMC)
  
  ################## Initialyzing ################## 
  ### Adding new column.
  df.input$min_genotype_class_count <- NA
  
  #idx = 1:nrow(df.input) # loop over all SNPs
  #idx = 1:1000 # loop over subset (for testing)
  
  ################ CPU Parameters #########################
  #param.N_cores <- detectCores() # OSX --> 8
  param.N_cores <- 4
  print(paste("param.N_cores:", param.N_cores))
  registerDoMC(param.N_cores)
  print(paste("number of CPUs used:", getDoParWorkers()))
  
  
  ################## Main loop ################## 
  time.start.main_loop <- proc.time()
  #list.par_analysis <- foreach (i=idx, .packages=c("plyr")) %dopar% {
  vector.min_genotype_class_count <- foreach (i=idx, .combine="c") %dopar% {
  #for (i in idx) {
    print(sprintf("#%d/#%d", i, length(idx)))
    
    name.probe <- df.input[i, "probename"]
    name.snp1 <-df.input[i, "snp1"]
    name.snp2 <- df.input[i, "snp2"]

    # Extract data
    snp1 <- geno[, colnames(geno) == name.snp1]
    snp2 <- geno[, colnames(geno) == name.snp2]
    probe <- df.probes[, colnames(df.probes) == name.probe]
    
    #print(name.snp1)
    #print(name.snp2)
    
    snp1.allele <- factor(snp1,levels=c("0", "1", "2", NA), exclude=NULL)
    snp2.allele <- factor(snp2,levels=c("0", "1", "2", NA), exclude=NULL)
    #print(snp1.allele)
    #print(snp2.allele)
    tab.allele <- table(data.frame(snp1.allele, snp2.allele))
        #                   snp2.allele
        # snp1.allele   0   1   2 <NA>
        #     0         0   0   4    0
        #     1         0   9  77    0
        #     2         2  91 642    0
        #     <NA>      0   0   7    0
    
    df.twolocus <- as.data.frame(tab.allele) # this is the 4x4 matrix/table
        #     snp1.allele	snp2.allele	Freq
        #     0	0	0
        #     1	0	0
        #     2	0	2
        #     NA	0	0
        #     0	1	0
        #     1	1	9
        #     2	1	91
        #     NA	1	0
        #     0	2	4
        #     1	2	77
        #     2	2	642
        #     NA	2	7
        #     0	NA	0
        #     1	NA	0
        #     2	NA	0
        #     NA	NA	0
    
    
    df.twolocus.narm <- na.omit(df.twolocus) # this is the 3x3 matrix/table
        #     snp1.allele	snp2.allele	Freq
        #     1	0	0	0
        #     2	1	0	0
        #     3	2	0	2
        #     5	0	1	0
        #     6	1	1	9
        #     7	2	1	91
        #     9	0	2	4
        #     10	1	2	77
        #     11	2	2	642
    
    min_genotype_class_count <- min(df.twolocus.narm$Freq)
    

    return(min_genotype_class_count) # # parallel | not sure that return() is needed

} # END for-loop

### Timing
time.end.main_loop <- proc.time()
time.elapsed.main_loop <- time.end.main_loop[3] - time.start.main_loop[3]
print(sprintf("Time elapsed: %.1f sec [%.1f min]", time.elapsed.main_loop, time.elapsed.main_loop/60))

df.input[idx, "min_genotype_class_count"] <- vector.min_genotype_class_count

################## Return value ################## 
#df.output <- subset(df.input, keep==TRUE, select=-keep) # subsetting and removing "keep" column
df.output <- df.input

return(df.output)

} # END function

