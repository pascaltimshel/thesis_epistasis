############### SYNOPSIS ###################
# CLASS: script; data/table generative
# PURPOSE: Generate NULL interactions with as few "true positives" as possible

# STEPS
# 1) define function with restrictions on permutations
# 2) run function
# 3) (make a few plots)

###########################################

library(ggplot2)
library(permute)
library(tools) # for file_path_sans_ext()

rm(list=ls())

wd <- path.expand('~/git/epistasis/interactome_fit-hic-c/interactome_null')
setwd(wd)

###################### TODO ####################
#1) *SEMI IMPORTANT*: fix the script to take into account that some positions on the genome participate in several interactions.
  # --> this means that the current implementation may contain a few "true positives".
  # --> to fix this, load in "chr:pos" in the table and permute these instead.
  # COMPLETED this task 01/28/2015
#2) find out how many theoretical "restricted permutations", n_perm_max, that exists as a function of length(x). 
  # --> Print warning if n_perm > n_perm_max

###################### SOURCE ####################
source(file="function_perm_restricted.R")
##################################################

###################### Read interaction table ####################
hic_cell_type <- "hESC" # "hESC" OR "hIMR90"

#p.q.threshold <- 1e-06
#p.q.threshold <- 1e-07
#p.q.threshold <- 1e-08
#p.q.threshold <- 1e-09
#p.q.threshold <- 1e-10

set.seed(1) # Important to set seed for REPRODUCIBLE results
n_perm <- 1000

for (p.q.threshold in c(1e-12,1e-13,1e-14,1e-15,1e-16,1e-17,1e-18)) {
#for (p.q.threshold in c(1e-12)) {
  time_start <- proc.time()
  
  str.path <- "/Users/pascaltimshel/p_HiC/Ferhat_Ay_2014/interaction_tables/interation_table.fit-hi-c.nosex.interchromosomal.%s.q_%s.txt" # e.g. interation_table.fit-hi-c.nosex.interchromosomal.hIMR90.q_1e-07.txt
  file.interaction_table <- sprintf(str.path, hic_cell_type, p.q.threshold)
  file.interaction_table
  
  df.interaction_table <- read.table(file=file.interaction_table, h=T, sep="\t", stringsAsFactors=F)
  
  
  ### Safety check: make sure the correct SORTED table is loaded ###
  stopifnot(all(df.interaction_table$chrA <= df.interaction_table$chrB)) # --> *MUST* be TRUE!

  
  #################### Run function ####################
  set.seed(1) # Important to set seed for REPRODUCIBLE results
  x <- paste0(df.interaction_table$chrB,":", df.interaction_table$posB)
  r.list <- perm_restricted(x, n_perm)
  df.perm <- r.list[[1]]
  df.perm.stats <- r.list[[2]]
  ######################################################
  
  ###### Make diagnostics ######
  ### Attempts histogram
  qplot(df.perm.stats$attempts, geom='histogram') + labs(title="Distribution of number of attempts")
  basename.plot <- sprintf("distribution_of_number_of_attempts_%s_nperm_%s_q_%s.pdf", hic_cell_type, n_perm, p.q.threshold)
  file.plot <- file.path(dirname(file.interaction_table), basename.plot)
  file.plot
  ggsave( file=file.plot )
  
  
  ### Number of duplicated interactions across all 'experiments'
  df.perm.dup <- data.frame(n_duplicates=apply(df.perm, 1, function(row) {sum(duplicated(row))})) # finding the number of indentical null for each interaction
  #x <- df.perm.dup[df.perm.dup>0]
  ### "Normalized histogram" (frequency)
  #ggplot(df.perm.dup, aes(x=n_duplicates)) + stat_bin(aes(y=..count../sum(..count..))) + labs(title="Distribution of number of duplicated interactions", x="Number of duplicated interactions", y="Frequency")
  ### Histogram (counts)
  ggplot(df.perm.dup, aes(x=n_duplicates)) + geom_histogram() + labs(title="Distribution of number of duplicated interactions", x="Number of duplicated interactions", y="Frequency")
  basename.plot <- sprintf("distribution_of_number_of_duplicated_interactions_%s_nperm_%s_q_%s.pdf", hic_cell_type, n_perm, p.q.threshold)
  file.plot <- file.path(dirname(file.interaction_table), basename.plot)
  file.plot
  ggsave( file=file.plot )
  
  ###################### EXPORT ######################
  ### Concatenate data frame 
  df.perm.concat <- data.frame(hic_1=seq(x), df.perm)
  
  ########## Validation steps ##########
  ### 1) The sum of each columns should be the same for all columns. This is because we are recycling indicies.
  colsum.df.perm.concat <- colSums(df.perm.concat)
  all(colsum.df.perm.concat == colsum.df.perm.concat[1]) # MUST BE TRUE. NB: the index "1" is abitrary
  ### 2) ???
  
  
  #####################################
  
  ### Setting pathname
  file.interaction_table.basename.sans_ext <- file_path_sans_ext(basename(file.interaction_table)) # removing trailing ".txt"
  file.interaction_table.basename.sans_ext
  file.null_table.basename.sans_ext <- sub('interation_table', 'null_table', file.interaction_table.basename.sans_ext) # regex substitution
  file.null_table.sans_ext <- file.path(dirname(file.interaction_table), file.null_table.basename.sans_ext)
  file.null_table <- sprintf("%s.nperm_%s.txt", file.null_table.sans_ext, n_perm)
  file.null_table
  
  ### 
  write.table(df.perm.concat, file=file.null_table, col.names=T, row.names=F, quote=F, sep="\t")
  #?write.table
  
  time_elapsed = proc.time() - time_start
  print(sprintf("Time elapsed, q=%s: %s", p.q.threshold, time_elapsed[3]))
}

