library(data.table) # seriously good package for bigger data sets.
#https://www.datacamp.com/community/tutorials/data-table-cheat-sheet
setDTthreads(4) #4 cpus. set this to 1 if you're unsure

#read tsv file list for individual, per-parcel data file
file_list <- fread('file_list.csv', header = FALSE, col.names = 'file')

#each data table in data_list is a dump from a volume with parcel info. The i,
#j, k values are the 3d cooridinates (not MNI) that let you map between the data
#tables. the `value` column is the parcel number
index_cols <- c('i', 'j', 'k')

if(!file.exists('parcel_data.rds')){
  data_list <- lapply(file_list$file, function(filename){
    d <- fread(filename, header = FALSE, col.names = c(index_cols, 'value'))
  })
  names(data_list) <- basename(file_list$file)
  saveRDS(data_list, 'parcel_data.rds')
} else {
  data_list <- readRDS('parcel_data.rds')
}


#(there is also one tsv with all of them, but I think it will be harder to work with)
#all_data <- fread('all_parcels.tsv', header = FALSE, col.names = c(index_cols, basename(file_list$file)))

#we need to integrate parcel-network information. For now, I'm going to create a
#dummy mapping, but supply the actual mapping here.
glasser_networks <- unique(data_list$Glasser_HCPMMP1_on_MNI152_ICBM2009a_nlin.2mm.tsv[, 'value'])
#this creates a new column with a random number 1-7. `.N` is a special
#data.table variable that's the number of rows
glasser_networks[, network := sample(1:7, .N, replace = TRUE)] 
#do the same for schaefer...
schaefer_networks <- unique(data_list$Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2mm.tsv[, 'value'])
schaefer_networks[, network := sample(1:7, .N, replace = TRUE)]

#Put the parcel information into the full data file. You'll do this for each
#parcellation.
data_list$Glasser_HCPMMP1_on_MNI152_ICBM2009a_nlin.2mm.tsv <- data_list$Glasser_HCPMMP1_on_MNI152_ICBM2009a_nlin.2mm.tsv[glasser_networks, on = 'value']
data_list$Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2mm.tsv <- data_list$Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2mm.tsv[schaefer_networks, on = 'value']

#Here's how to merge 2 of the files in an efficient way
sch_glass <- data.table::merge.data.table(x = data_list$Glasser_HCPMMP1_on_MNI152_ICBM2009a_nlin.2mm.tsv,
                                            y = data_list$Schaefer2018_100Parcels_7Networks_order_FSLMNI152_2mm.tsv, 
                                            by = index_cols, all = TRUE) #all = TRUE is important

#column value.x has the glasser network info and value.y has the schaefer network info.
cols <- c('network.x', 'network.y')

sch_glass[, (cols) := lapply(.SD, function(x){
  fifelse(is.na(x), 0, x)
}), .SDcols = cols]
         
#to get the overlap for just one network, you probably want a data table where
#the value in network.x OR network.y corresponds to the network of interest
sch_glass_net1 <- sch_glass[network.x == 1 | network.y ==1]
sch_glass_net1[, overlap := (network.x == network.y) & (network.x == 1)]
sch_glass_net1[, sum(overlap)]
