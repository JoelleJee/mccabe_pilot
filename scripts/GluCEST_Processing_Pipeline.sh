#!/bin/bash

#This script post-processes GluCEST data output by the Matlab software cest2d_TERRA_SYRP. This script requires that:
#1. The MP2RAGE processing script MP2RAGE_Processing_Pipeline.sh has been run
#2. The CEST data has been processed via the Matlab GUI cest2d_TERRA_SYRP and output in dicom format

#The processing pipeline includes:
	#dcm to nifti conversion for Matlab generated B0 maps, B1 maps, and B0B1-corrected GluCEST dicoms
	#B0 and B1 map thresholding of GluCEST images
	#CSF removal from GluCEST images
	#GluCEST brain masking
	#registration of atlases from MNI space to participant UNI images
	#registration of FAST segmentation and reward atlas slices to GluCEST images
	#generation of reward network anatomical and valence-encoding subcomponent masks

#######################################################################################################
## DEFINE PATHS ##

cest=/project/bbl_roalf_cmroicest/cest #path for processed GluCEST data
dicoms=/project/bbl_roalf_cmroicest/data
structural=/project/bbl_roalf_cmroicest/structural #path for processed structural output
base=/project/bbl_roalf_cmroicest #project path
ANTSPATH=/appl/ANTs-2.3.1/bin/
log=/project/bbl_roalf_cmroicest/logs/cest
#######################################################################################################
## IDENTIFY CASES FOR PROCESSING ##

for i in $(ls $dicoms)
do
case=${i##*/}
echo "CASE: $case"

#check for structural data
if [ -e $structural/$case/${case}_MPRAGE-processed.nii.gz ] && [ -e $structural/$case/fast/${case}_seg.nii.gz ]
then
echo "Structural Data exists for $case"
sleep 1.5
else
echo "Oh No! Structural Data is missing. Cannot process CEST! Run MP2RAGE_Processing_Pipeline.sh first."
sleep 1.5
fi

#check for GluCEST GUI data
if [ -d $dicoms/$case/${case}_B0MAP ] && [ -d $dicoms/$case/${case}_B1MAP ] && [ -d $dicoms/$case/${case}_B0B1CESTMAP ]
then
echo "CEST GUI Data exists for $case"
sleep 1.5
else
echo "Oh No! CEST GUI Data is missing. Cannot process CEST! Analyze this case with CEST_2d_TERRA first."
sleep 1.5
fi

if ! [ -d $cest/$case ] && [ -d $dicoms/$case/${case}_B0MAP ] && [ -d $dicoms/$case/${case}_B1MAP ] && [ -d $dicoms/$case/${case}_B0B1CESTMAP ] && [ -e $structural/$case/fast/${case}_seg.nii.gz ]
then
logfile=$log/${case}.log
log_files=$cest/$case/log_files

(
echo "--------Processing GluCEST data for $case---------"
sleep 1.5
#######################################################################################################
## CONVERT B0, B1, and B0B1-CORRECTED CEST FROM DCM TO NII ##

mkdir $cest/$case
mkdir $log_files

	for seq in B0MAP B1MAP B0B1CESTMAP
	do
	/project/bbl_projects/apps/melliott/scripts/dicom2nifti.sh -u -r Y -F $cest/$case/$case-$seq.nii $dicoms/$case/${case}_${seq}/*dcm
	done
#######################################################################################################
## THRESHOLD B0 AND B1 MAPS ##

#threshold b0 from -1 to 1 ppm (relative to water resonance)
fslmaths $cest/$case/$case-B0MAP.nii -add 10 $cest/$case/$case-B0MAP-pos.nii.gz # make B0 map values positive to allow for thresholding with fslmaths
fslmaths $cest/$case/$case-B0MAP-pos.nii.gz -thr 9 -uthr 11 $cest/$case/$case-B0MAP-thresh.nii.gz #threshold from -1(+10=9) to 1(+10=11)
fslmaths $cest/$case/$case-B0MAP-thresh.nii.gz -bin $cest/$case/$case-b0.nii.gz #binarize thresholded B0 map

#threshold b1 from 0.3 to 1.3
fslmaths $cest/$case/$case-B1MAP.nii -thr 0.3 -uthr 1.3 $cest/$case/$case-B1MAP-thresh.nii.gz #threshold from 0.3 to 1.3
fslmaths $cest/$case/$case-B1MAP-thresh.nii.gz -bin $cest/$case/$case-b1.nii.gz #binarize thresholded B1 map
#######################################################################################################
## ALIGN FSL FAST OUTPUT TO GLUCEST IMAGES ##

mkdir $cest/$case/fast
/project/bbl_projects/apps/melliott/scripts/extract_slice2.sh -MultiLabel $structural/$case/fast/${case}_seg.nii.gz $cest/$case/$case-B0B1CESTMAP.nii $cest/$case/fast/$case-2d-FAST.nii
gzip $cest/$case/fast/$case-2d-FAST.nii

/project/bbl_projects/apps/melliott/scripts/extract_slice2.sh $structural/$case/fast/${case}_prob_1.nii.gz $cest/$case/$case-B0B1CESTMAP.nii $cest/$case/fast/$case-2d-FASTGMprob.nii
gzip $cest/$case/fast/$case-2d-FASTGMprob.nii
#######################################################################################################
## APPLY THRESHOLDED B0 MAP, B1 MAP, and TISSUE MAP (CSF removed) TO GLUCEST IMAGES ##

#exclude voxels with B0 offset greater than +- 1 pmm from GluCEST images
fslmaths $cest/$case/$case-B0B1CESTMAP.nii -mul $cest/$case/$case-b0.nii.gz $cest/$case/$case-CEST_b0thresh.nii.gz

#exclude voxels with B1 values outside the range of 0.3 to 1.3 from GluCEST images
fslmaths $cest/$case/$case-CEST_b0thresh.nii.gz -mul $cest/$case/$case-b1.nii.gz $cest/$case/$case-CEST_b0b1thresh.nii.gz

#exclude CSF voxels from GluCEST images
fslmaths $cest/$case/fast/$case-2d-FAST.nii.gz -thr 2 $cest/$case/fast/$case-tissuemap.nii.gz
fslmaths $cest/$case/fast/$case-tissuemap.nii.gz -bin $cest/$case/fast/$case-tissuemap-bin.nii.gz
fslmaths $cest/$case/$case-CEST_b0b1thresh.nii.gz -mul $cest/$case/fast/$case-tissuemap-bin.nii.gz $cest/$case/$case-CEST-finalthresh.nii.gz
#######################################################################################################
## MASK THE PROCESSED GLUCEST IMAGE ##

fslmaths $cest/$case/$case-B1MAP.nii -bin $cest/$case/CEST-masktmp.nii.gz
fslmaths $cest/$case/CEST-masktmp.nii.gz -ero -kernel sphere 1 $cest/$case/CEST-masktmp-er1.nii.gz
fslmaths $cest/$case/CEST-masktmp-er1.nii.gz -ero -kernel sphere 1 $cest/$case/CEST-masktmp-er2.nii.gz
fslmaths $cest/$case/CEST-masktmp-er2.nii.gz -ero -kernel sphere 1 $cest/$case/$case-CEST-mask.nii.gz
fslmaths $cest/$case/$case-CEST-finalthresh.nii.gz -mul $cest/$case/$case-CEST-mask.nii.gz $cest/$case/$case-GluCEST.nii.gz #final processed GluCEST Image
#######################################################################################################
#clean up and organize, whistle while you work
mv $cest/$case/*masktmp* $log_files
mv $cest/$case/*log* $log_files
mv $cest/$case/$case-B0MAP-pos.nii.gz $log_files
mv $cest/$case/$case-B0MAP-thresh.nii.gz $log_files
mv $cest/$case/$case-B1MAP-thresh.nii.gz $log_files

mkdir $cest/$case/orig_data
mv $cest/$case/$case-B0MAP.nii $cest/$case/$case-B1MAP.nii $cest/$case/$case-B0B1CESTMAP.nii $cest/$case/orig_data
#######################################################################################################
## REGISTER ATLASES TO UNI IMAGES AND GLUCEST IMAGES ##

mkdir $cest/$case/atlases

#Harvard Oxford Atlasess
for atlas in cort sub
do
	antsApplyTransforms -d 3 -r $structural/$case/${case}_MPRAGE-masked.nii.gz \
		-i $structural/MNI_Templates/HarvardOxford/HarvardOxford-$atlas-maxprob-thr25-1mm.nii.gz \
		-n MultiLabel -o $structural/$case/atlases/${case}-HarvardOxford-$atlas.nii.gz  \
		-t [$structural/$case/MNI_transforms/${case}_MPRAGEinMNI-0GenericAffine.mat,1] \
		-t $structural/$case/MNI_transforms/${case}_MPRAGEinMNI-1InverseWarp.nii.gz
	/project/bbl_projects/apps/melliott/scripts/extract_slice2.sh \
		-MultiLabel $structural/$case/atlases/${case}-HarvardOxford-$atlas.nii.gz \
		$cest/$case/orig_data/$case-B0B1CESTMAP.nii $cest/$case/atlases/${case}-2d-HarvardOxford-$atlas.nii
	
	gzip $cest/$case/atlases/${case}-2d-HarvardOxford-$atlas.nii
	
	fslmaths $cest/$case/atlases/$case-2d-HarvardOxford-$atlas.nii.gz \
		-mul $cest/$case/fast/$case-tissuemap-bin.nii.gz \
		$cest/$case/atlases/$case-2d-HarvardOxford-$atlas.nii.gz

	fslmaths $cest/$case/atlases/$case-2d-HarvardOxford-$atlas.nii.gz \
		-bin $cest/$case/atlases/$case-2d-HarvardOxford-$atlas-bin.nii

done


echo -e "\n$case SUCCESFULLY PROCESSED\n\n\n"
)  | tee "$logfile"
else
echo "$case is either missing data or already processed. Will not process"
sleep 1.5
fi
done
