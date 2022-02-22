# if (!requireNamespace("tidyverse")) {
#   install.packages("tidyverse")
#   library(tidyverse)
# }

output = '/project/bbl_roalf_cmroicest/output_measures'
all_data = dplyr::tibble()

for (sub_dir in list.dirs(output, recursive = FALSE)) {
  subject = basename(sub_dir)
  sub_data = file.path(sub_dir, paste0(subject, '-HarvardOxfordROI-GluCEST-measures.csv'))
  sub_data = read_tsv(sub_data)
  all_data = dplyr::bind_rows(all_data, sub_data)
}

write_tsv(all_data, file.path(output, 'GluCEST-HarvardOxfordROI-Measures.tsv'))
