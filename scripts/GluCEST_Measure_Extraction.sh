#!/bin/bash

#This script calculates GluCEST contrast and gray matter density measures

#######################################################################################################
## DEFINE PATHS ##

cest=/project/bbl_roalf_cmroicest/cest #path to processed GluCEST data
outputpath=/project/bbl_roalf_cmroicest/output_measures

# HARVARD OXFORD

for atlas in cort sub
do
	touch $outputpath/GluCEST-HarvardOxford-$atlas-measures.tsv
	echo "Subject	HarvardOxford_${atlas}_CEST_mean	HarvardOxford_CEST_numvoxels	HarvardOxford_CEST_SD" >> \
		$outputpath/GluCEST-HarvardOxford-$atlas-measures.tsv
done

for i in $(ls $cest)
do
	case=${i##*/}
	echo "CASE: $case"
	mkdir $outputpath/$case

	for atlas in cort sub
	do
		#quantify GluCEST contrast for each participant
		3dROIstats -mask $cest/$case/atlases/$case-2d-HarvardOxford-$atlas.nii.gz \
			-zerofill NaN -nomeanout -nzmean -nzsigma -nzvoxels -nobriklab -1DRformat \
			$cest/$case/$case-GluCEST.nii.gz >> $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv
		#format participant-specific csv
		sed -i 's/name/Subject/g' $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv
		cut -f2-3 --complement $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv >> \
			$outputpath/$case/tmp.tsv
		mv $outputpath/$case/tmp.tsv $outputpath/$case/$case-HarvardOxfordROI-GluCEST-$atlas-measures.tsv

		#quantify GluCEST contrast for each participant
		3dROIstats -mask $cest/$case/atlases/$case-2d-HarvardOxford-$atlas-bin.nii.gz \
			-zerofill NaN -nomeanout -nzmean -nzsigma -nzvoxels -nobriklab -1DRformat \
			$cest/$case/$case-GluCEST.nii.gz >> $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv
		#format participant-specific csv
		sed -i 's/name/Subject/g' $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv
		cut -f2-3 --complement $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv >> \
			$outputpath/$case/tmp.tsv
		mv $outputpath/$case/tmp.tsv $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv
		#enter participant GluCEST contrast data into master spreadsheet
		sed -n "2p" $outputpath/$case/$case-HarvardOxford-GluCEST-$atlas-measures.tsv >> \
			$outputpath/GluCEST-HarvardOxford-$atlas-measures.tsv
	done
done

