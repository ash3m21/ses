# !!! attention define_treatment_controls_outcomes and recode_variables_in_dat
# has to be changed according to specific analysis
# better redefine these two files  
set.seed(123)
library(here)
library(tidyverse)
library(rlang)
library(skimr)
library(furrr)
library(limma)
library(recipes)
library(parsnip)
library(workflows)
library(Biobase)
library(enrichplot)
library(dbr) # my package

walk(dir(path = here("R"), full.names = TRUE), source)
fit_m4 <- partial(fit_m4, n_perm = 1000) # specify n_perm

# explicitly assign ncomp as the smallest number of table signatures gene numbers
# attention for gene set smaller than 10
ncomp <- 10
fit_pca_util <- partial(fit_pca_util, ncomp = ncomp) # specify n_perm
print(abbreviations)
funcs <- str_subset(abbreviations$shorthand, "^m")
funcs <- funcs %>% str_subset("m[7-8]")

############################################################
# LOAD DATA, DEFINE VARIABLES, RECODE VARIABLES
############################################################
# load custom ancestry PC
dt_color_snp <- readRDS("/home/share/dna_ancestry/dna/dt_color_snp.rds")
fit_bespoke <- function(gene_set_name, p_eqtl) {
  load_data(reconciled = FALSE, remove_inflam = FALSE)

  # find the important PCs to be included for each analysis
  ancestryPC <- get_PC_dim(gene_set_name, p_eqtl)
  # define_treatments_and_controls_bespoke(gene_set_name, ancestryPC)
  define_treatments_and_controls_snps(gene_set_name, ancestryPC)
  custom_PCA <- readRDS(str_c("/home/share/dna_ancestry/dna/custom_PCA_", gene_set_name, "_", p_eqtl, ".rds"))
  custom_PCA <- custom_PCA %>%
    select(-fid) %>%
    mutate(AID = AID %>% as.character())
  recode_variables_in_dat_bespoke(custom_PCA)

  example0 <-
    args %>%
    # filter(names(controls) =="ancestryPC") %>%
    mutate(
      out = pmap(., safely(model_fit), funcs),
      control_set = names(controls)
    )

  example1 <-
    args %>%
    # filter(names(controls) =="ancestryPC") %>%
    mutate(gene_set_name = "whole_genome_and_tfbm") %>%
    mutate(
      out = pmap(., safely(model_fit), funcs),
      control_set = names(controls)
    )

  return(list(example0 = example0, example1 = example1))
}

table1 <-
  c(
    "ctra_mRNA",
    "inflame_mRNA",
    "interferon_mRNA",
    "AntBIntF_mRNA",
    # "antibody_mRNA", #only 1 gene
    "inflam1k_mRNA",
    "aging_mRNA",
    "aging_up_mRNA",
    "aging_down_mRNA"
  )

p_eqtl <- c(0.05, 1e-2, 1e-3, 1e-4, 1e-5, 1e-6, 1e-7, 1e-8, 1e-9, 1e-10)

args_eqtl <- crossing(table1, p_eqtl)
plan(multicore, workers = 40)
# debugonce(fit_bespoke)
example_bespoke <- args_eqtl %>%
  mutate(out = furrr::future_pmap(list(gene_set_name = table1, p_eqtl = p_eqtl), safely(fit_bespoke)))

example_bespoke %>% saveRDS("./xxx.rds")
# example_bespoke %>% saveRDS("./user_wx/bespoke_snps.rds")
# example_bespoke %>% saveRDS("./user_wx/bespoke_v4.rds")
# v2 :only ancestry controls
# v3 : all 3 sets of controls
# v4: corrected kept dim first row not as colnames
# v2 v3 and v4 results are same except mediation as it is based on bootstraping estimation
