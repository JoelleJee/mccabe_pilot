#!/bin/bash

#This script processes 7T Terra MP2RAGE data.
#The processing pipeline includes:
	#UNI and INV2 dicom to nifti conversion
	#structural brain masking
	#ANTS N4 bias field correction
	#FSL FAST (for tissue segmentation and gray matter probability maps)
	#UNI to MNI registration with ANTS SyN (rigid+affine+deformable syn)

#######################################################################################################
## DEFINE PATHS ##

structural=/project/bbl_roalf_cmroicest/structural #path for processed structural output
dicoms=/project/bbl_roalf_cmroicest/data #path to dicoms
base=/project/bbl_roalf_cmroicest #project path
ANTSPATH=/appl/ANTs-2.3.1/bin/

#######################################################################################################
## IDENTIFY CASES FOR PROCESSING ##

for i in $(ls $dicoms)
do
case=${i##*/}
echo "CASE: $case"

if ! [ -d $structural/$case ] && [ -d $dicoms/$case/*MPRAGE ]

then
logfile=$base/logs/structural/$case.log
log_files=$structural/$case/log_files
{
echo "--------Processing structural data for $case---------"
sleep 1.5
mkdir $structural/$case
mkdir $structural/$case/fast
mkdir $structural/$case/MNI_transforms
mkdir $structural/$case/atlases
mkdir $log_files #Store logfile and intermediate files here.
#######################################################################################################
## STRUCTURAL DICOM CONVERSION ##

#convert MPRAGE
/project/bbl_projects/apps/melliott/scripts/dicom2nifti.sh -u -F $structural/$case/${case}_MPRAGE.nii $dicoms/$case/*MPRAGE/*dcm
gzip $structural/$case/${case}_MPRAGE.nii
#######################################################################################################
## STRUCTURAL BRAIN MASKING ##

#create initial mask with BET using INV2 image
bet $structural/$case/${case}_MPRAGE.nii.gz $structural/$case/${case}_bet -m -f 0.2
mv -f $structural/$case/${case}_bet.nii.gz $log_files/

#generate final brain mask
fslmaths $structural/$case/${case}_MPRAGE.nii.gz -mul $structural/$case/${case}_bet_mask.nii.gz $structural/$case/${case}_MPRAGE_masked.nii.gz
mv -f $structural/$case/${case}_bet_mask.nii.gz $log_files/

fslmaths $structural/$case/${case}_MPRAGE_masked.nii.gz -bin $structural/$case/${case}_bin-mask.nii.gz
mv $structural/$case/${case}_MPRAGE_masked.nii.gz $log_files

fslmaths $structural/$case/${case}_bin-mask.nii.gz -ero -kernel sphere 1 $structural/$case/${case}_MPRAGE-mask-er.nii.gz
mv -f $structural/$case/${case}_bin-mask.nii.gz $log_files/

#apply final brain mask to UNI and INV2 images
fslmaths $structural/$case/${case}_MPRAGE.nii.gz -mas $structural/$case/${case}_MPRAGE-mask-er.nii.gz $structural/$case/${case}_MPRAGE-masked.nii.gz
#######################################################################################################
## BIAS FIELD CORRECTION ##

N4BiasFieldCorrection -d 3 -i $structural/$case/${case}_MPRAGE-masked.nii.gz -o $structural/$case/${case}_MPRAGE-processed.nii.gz
#######################################################################################################
## FAST TISSUE SEGMENTATION ##

fast -n 3 -t 1 -g -p -o $structural/$case/fast/$case $structural/$case/${case}_MPRAGE-processed.nii.gz
#######################################################################################################
## UNI TO MNI152 REGISTRATION ##

#register processed UNI to MNI T1 template
antsRegistrationSyN.sh -d 3 -f $structural/MNI_Templates/MNI/MNI152_T1_1mm_brain.nii.gz -m $structural/$case/${case}_MPRAGE-processed.nii.gz -o $structural/$case/MNI_transforms/${case}_MPRAGEinMNI-
#######################################################################################################
#clean up sweep sweep
mv $structural/$case/${case}_MPRAGE.nii.gz $log_files/
mv $structural/$case/*log  $log_files/

echo -e "\n$case SUCCESFULLY PROCESSED\n\n\n"
} | tee "$logfile"
else
echo "$case is either missing structural dicoms or already processed. Will not process"
sleep 1.5
fi
done
