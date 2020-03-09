#!/usr/bin/env bash
#Filename pipeline.sh
#Usage: bash pipeline.sh
#Developer: Davide 'Duzzo' Fedeli
#Contact: d.fedeli6campus.unimib.it; fedeli.davide@hsr.it
#Requirements: MRtrix3; FreeSurfer; fsl

#make shure to set your subject direcory like this:
#
# .
# ├── 3DT1 (DICOM directory with T1 structural files)
# ├── b0rev (DICOM directory with b0 value in opposite phase encoding direction: AP)
# ├── fs_subj (freesurfer directory)
# ├── DWI (DICOM directory with DWI files in PA direction)
# └── pipeline.sh (this script)
#
# make sure to run recon-all FreeSurfer rescontstuction only on a non AC-PC oriented T1 image.
#
touch logfile.txt
toilet --gay CC
echo "********************************"
echo "initiating tractography pipeline"
echo "********************************"
echo "********************************" > logfile.txt
echo "initiating tractography pipeline" >> logfile.txt
echo "********************************" >> logfile.txt
date
date >> logfile.txt
echo "converting DICOM images into .mif files"
echo "converting DICOM images into .mif files" >> logfile.txt
mrconvert DWI/ dwi_raw.mif
date >> logfile.txt
echo "denoise the raw diffusion data"
echo "denoise the raw diffusion data" >> logfile.txt
dwidenoise dwi_raw.mif dwi_den.mif -noise noise.mif -nthreads 4
date >> logfile.txt
echo "calculate the difference between the raw and the denoised image"
echo "calculate the difference between the raw and the denoised image" >> logfile.txt
date >> logfile.txt
mrcalc dwi_raw.mif dwi_den.mif -subtract residual.mif
echo "perform Unringing to remove Gibb's ringing artefacts"
echo "perform Unringing to remove Gibb's ringing artefacts" >> logfile.txt
mrdegibbs dwi_den.mif dwi_den_unr.mif -axes 0,1 -nthreads 4
date >> logfile.txt
echo "calculate difference between the denoised image and the unringed image"
echo "calculate difference between the denoised image and the unringed image" >> logfile.txt
mrcalc dwi_den.mif dwi_den_unr.mif -subtract residualUnringed.mif
date >> logfile.txt
echo "*******************************************"
echo "initiating motion and distortion correction"
echo "*******************************************"
echo "*******************************************" >> logfile.txt
echo "initiating motion and distortion correction" >> logfile.txt
echo "*******************************************" >> logfile.txt
date >> logfile.txt
echo "extract b0-images from dwi_den_unr.mif and calculate the mean"
echo "extract b0-images from dwi_den_unr.mif and culate the mean" >> logfile.txt
date >> logfile.txt
dwiextract dwi_den_unr.mif - -bzero | mrmath - mean mean_b0_AP.mif -axis 3
echo "calculate the mean image of the b0s in the reversed phase-encoded direction (in this case, PA)"
echo "calculate the mean image of the b0s in the reversed phase-encoded direction (in this case, PA)" >> logfile.txt
date >> logfile.txt
mrconvert b0rev/ b0rev.mif
mrconvert b0rev/ - | mrmath - mean mean_b0_PA.mif -axis 3
echo "concatenate the two mean b0-images into one file"
echo "concatenate the two mean b0-images into one file" >> logfile.txt
date >> logfile.txt
mrcat mean_b0_AP.mif mean_b0_PA.mif  -axis 3 b0_pair.mif
echo "run motion and distortion correction"
echo "run motion and distortion correction" >> logfile.txt
date >> logfile.txt
dwipreproc dwi_den_unr.mif dwi_den_unr_preproc.mif -pe_dir AP -rpe_pair -se_epi b0_pair.mif -nthreads 4 -eddy_options " --slm=linear --repol --data_is_shelled -v"
#note that this command will take around an hour when using a 16GB RAM 4cores workstation. If Cuda 9.1 or 8.0 is installed this will greatly reduce the required processing time


#echo "perform bias field correction to improve the brain mask estimation"
#echo "perform bias field correction to improve the brain mask estimation" >> logfile.txt
#date >> logfile.txt
# dwibiascorrect can be used with the fsl or ant flag, try both
#this step can actually deteriorate your mask! check if there is any benefit
#the usage of the -ants flag in suggested while -fsl is discouraged
#if ANTS works on your computer you can actually enable unbiasing.
#dwibiascorrect -ants dwi_den_unr_preproc.mif dwi_den_unr_preproc_unbiased.mif -bias bias.mif
#dwibiascorrect -ants dwi_den_unr_preproc.mif dwi_den_unr_preproc_unbiased.mif -bias bias.mif

echo "mask preprocessed data with bias image"
echo "mask preprocessed data with bias image" >> logfile.txt
date >> logfile.txt
dwi2mask dwi_den_unr_preproc.mif mask_den_unr_preproc.mif
echo "*************************************************"
echo "perform Fiber Orientation Distribution (FOD) est."
echo "*************************************************"
echo "*************************************************" >> logfile.txt
echo "perform Fiber Orientation Distribution (FOD) est." >> logfile.txt
echo "*************************************************" >> logfile.txt
#now we will do fiber orientation distribution estimation.
date >> logfile.txt
echo "estimate response function of wm, gm and csf (Dhollander et al., 2016)"
echo "estimate response function of wm, gm and csf (Dhollander et al., 2016)" >> logfile.txt
date >> logfile.txt
dwi2response dhollander dwi_den_unr_preproc.mif wm.txt gm.txt csf.txt -voxels voxels.mif -nthreads 3 -force
#now look at your data with shview wm.txt
echo "perform FOD to estimate voxelwise the orientation of all fibers crossing each voxel"
echo "algorithm: msmt multi shell multi tissue cosntrained spherical deconvolution"
echo "perform FOD to estimate voxelwise the orientation of all fibers crossing each voxel" >> logfile.txt
echo "algorithm: msmt multi shell multi tissue cosntrained spherical deconvolution" >> logfile.txt
date >> logfile.txt
dwi2fod msmt_csd dwi_den_unr_preproc.mif -mask mask_den_unr_preproc.mif wm.txt wmfod.mif gm.txt gmfod.mif csf.txt csffod.mif -force
#the following steps are to check the results of FOD. Check for crossing fibers correctly resolved and inspect location where crossing fibers could be. Check if estimation of FOD was performed in WM and not in GM and CSF
mrconvert -coord 3 0 wmfod.mif - | mrcat csffod.mif gmfod.mif - vf.mif -force
#to visualize: mrview vf.mif -odf.load_sh wmfod.mif
echo "now perform intensity normalization to correct for global intensity differences"
echo "now perform intensity normalization to correct for global intensity differences" >> logfile.txt
date >> logfile.txt
mtnormalise wmfod.mif wmfod_norm.mif gmfod.mif gmfod_norm.mif csffod.mif csffod_norm.mif -mask mask_den_unr_preproc.mif
mrconvert -coord 3 0 wmfod_norm.mif - | mrcat csffod_norm.mif gmfod_norm.mif - vf_norm.mif
#to visualize: mrview vf_norm.mif -odf.load_sh wmfod_norm.mif
echo "**********************************"
echo "creation of whole brain tractogram"
echo "**********************************"
echo "**********************************" >> logfile.txt
echo "creation of whole brain tractogram" >> logfile.txt
echo "**********************************" >> logfile.txt
date >> logfile.txt
echo "preparing data for anatomically constrained tractography (ACT) to increase biological plausibility of stramlines"
echo "preparing data for anatomically constrained tractography (ACT) to increase biological plausibility of stramlines" >> logfile.txt
mrconvert 3DT1/ T1_raw.mif -nthreads 4
5ttgen fsl T1_raw.mif 5tt_nocoreg.mif -nthreads 4 -nocleanup
echo "compute mean of b0 images"
echo "compute mean of b0 images" >> logfile.txt
date >> logfile.txt
dwiextract dwi_den_unr_preproc.mif - -bzero | mrmath - mean mean_b0_preprocessed.mif -axis 3
mrconvert mean_b0_preprocessed.mif mean_b0_preprocessed.nii.gz
bet mean_b0_preprocessed.nii.gz mean_b0_preprocessed_BET.nii.gz # -c 47 49 30 -f 0.4
# "Visually check BET accuracy and tweak BET command if needed."
mrconvert 5tt_nocoreg.mif 5tt_nocoreg.nii.gz
echo "Register mean_b0_preprocessed_BET with T1_BET (found inside 5ttgen temp folder)"
echo "Register mean_b0_preprocessed_BET with T1_BET (found inside 5ttgen temp folder)" >> logfile.txt
date >> logfile.txt
mrconvert 3DT1/ T1_raw.nii.gz -datatype uint16le -force
bet T1_raw.nii.gz T1_raw_bet.nii.gz
epi_reg --epi=mean_b0_preprocessed.nii.gz --t1=T1_raw.nii.gz --t1brain=T1_raw_bet.nii.gz --out=diff_epi_reg_fsl --noclean -v

echo "convert fsl transform to MRtrix3 transform"
echo "convert fsl transform to MRtrix3 transform" >> logfile.txt
date >> logfile.txt
transformconvert diff_epi_reg_fsl.mat mean_b0_preprocessed.nii.gz T1_raw.nii.gz flirt_import diff2struct_mrtrix.txt -force
echo " Apply (inverse) transform to the 5ttgen data"
echo " Apply (inverse) transform to the 5ttgen data" >> logfile.txt
date >> logfile.txt
mrtransform 5tt_nocoreg.mif -linear diff2struct_mrtrix.txt -inverse 5tt_coreg.mif -force
# check the result with: mrview dwi_den_unr_preproc.mif -overlay.load 5tt_nocoreg.mif -overlay.colourmap 2 -overlay.load 5tt_coreg.mif -overlay.colourmap 1
echo "preparing mask of streamline seeding by defining the gm/wm boundary"
echo "preparing mask of streamline seeding by defining the gm/wm boundary" >> logfile.txt
date >> logfile.txt
# You can also create an additional streamline file by inputting a subcortical region mask only, in order to get only those fibers between subcortical regions and combine the results
5tt2gmwmi 5tt_coreg.mif gmwmSeed_coreg.mif
echo "perform probabilistic tractography with ACT with 1 million streamlines"
echo "perform probabilistic tractography with ACT with 1 million streamlines" >> logfile.txt
date >> logfile.txt
tckgen -act 5tt_coreg.mif -backtrack -seed_gmwmi gmwmSeed_coreg.mif -select 1000000 wmfod_norm.mif tracks_1mio.tck -nthreads 4
#10 mio è troppo.. si potrebbe valutare con 5 mio
echo "perform probabilistic tractography with ACT with 100k streamlines"
echo "perform probabilistic tractography with ACT with 100k streamlines" >> logfile.txt
date >> logfile.txt
tckgen -act 5tt_coreg.mif -backtrack -seed_gmwmi gmwmSeed_coreg.mif -select 100k wmfod_norm.mif tracks_100k.tck -nthreads 4
#qui posso usare anche solo 100k. 100k o più è recommended. Forse 1 milione è anche gestibile
#faccio un connettoma, utile per fare diagnosi
echo "create and map a connectome for visual checking"
echo "create and map a connectome for visual checking" >> logfile.txt
date >> logfile.txt
tckmap tracks_100k.tck TDI.mif -vox 3 -dec
#-mrtrix command tckmap generates all variants of TWI (track Weighted Images):
#-contrast per streamline (e.g. values from a supplied image)
#-per-streamline statistic (e.g. mean value along streamline)
#-per-voxel statistic (e.g. mean value from all intersecting streamlines)
#for more details read
#Calamante et al., Neuroimage 2012:59,2494-2503
#puoi vedere tutto con mrview dwi_den_unr_preproc.mif -tractography.load tracks_10mio.tck  mrview dwi_den_unr_preproc.mif -tractography.load tracks_1mio.tck
echo "choosing randomly a subset of the 1 million tracks with tckedit"
echo "choosing randomly a subset of the 1 million tracks with tckedit" >> logfile.txt
date >> logfile.txt
tckedit tracks_1mio.tck -number 200k smallerTracks_200k.tck
#visualizza con: mrview dwi_den_unr_preproc.mif -tractography.load smallerTracks_200k.tck
echo "**********************************"
echo "reducing the number of streamlines"
echo "**********************************"
echo "**********************************" >> logfile.txt
echo "reducing the number of streamlines" >> logfile.txt
echo "**********************************" >> logfile.txt
echo "reduce the number of streamlines by filtering the tractogram with SIFT-2"
echo "reduce the number of streamlines by filtering the tractogram with SIFT-2" >> logfile.txt
date >> logfile.txt
#reduce the number of streamlines by filtering the tractogram to reduce CSD-based bias in overestimation of longer tracks compared to shorter tracks
#check SIFT page to find info on the different filtering options and find the one that best fits your needs
#use ACT to improve biological plausibility!
#tcksift -act 5tt_coreg.mif -term_number 100k tracks_1mio.tck wmfod_norm.mif sift_100k.tck -nthreads 6
#mrview dwi_den_unr_preproc.mif -tractography.load sift_100k.tck
#tcksift will take several hours to complete
#check tutorial! Tournier suggests tcksift2, which is not only better, but also faster!
#do not display all at once, but just some subsets
tcksift2 -act 5tt_coreg.mif tracks_1mio.tck wmfod_norm.mif weights_1mio.csv -nthreads 6
tckmap tracks_1mio.tck TDI_05_weighted.mif -tck_weights_in weights_1mio.csv -vox 0.5 -dec -force
tckedit tracks_1mio.tck -tck_weights_in weights_1mio.csv sift_1mio.tck
tckedit tracks_1mio.tck -number 200k -tck_weights_in weights_1mio.csv sift_200k.tck
#let's view a subset of even smaller tracks!
tckedit tracks_1mio.tck -number 10k -tck_weights_in weights_1mio.csv small_sift_10k.tck -force
tckedit tracks_1mio.tck -number 10k superSmall_10k.tck -force
echo "SIFT2 has successfully created 200k and 10k tractograms"
echo "SIFT2 has successfully created 200k and 10k tractograms" >> logfile.txt
date >> logfile.txt
#perform a ROI analysis by defining a tract passing trough a region with these real world coordinates (CST)
#tckedit -include 8,-17,-18,3 tracks_1mio.tck -tck_weights_in weights_10mio.csv cst_sift2.tck -force; mrview dwi_den_unr_preproc.mif -tractography.load cst_sift2.tck
echo "register T1 to diffusion space to view tracks in subject space"
echo "register T1 to diffusion space to view tracks in subject space" >> logfile.txt
date >> logfile.txt
#use diff2struct_mrtix.txt to register the T1_raw.mif to diffusion space to obtain T1_coreg.mif and view the track-files on the T1-image
mrtransform T1_raw.mif -linear diff2struct_mrtrix.txt -inverse T1_coreg.mif
#mrview T1_coreg.mif -tractography.load cst_sift2.tck
echo "**********************************"
echo "connectome construction"
echo "**********************************"
echo "**********************************" >> logfile.txt
echo "connectome construction" >> logfile.txt
echo "**********************************" >> logfile.txt
date >> logfile.txt
echo "prepare atlas for structural connectivity analysis (freesurfer's aparc+aseg)"
echo "prepare atlas for structural connectivity analysis (freesurfer's aparc+aseg)"
date >> logfile.txt
labelconvert fs_subj/mri/aparc+aseg.mgz $FREESURFER_HOME/FreeSurferColorLUT.txt ~/mrtrix3/share/mrtrix3/labelconvert/fs_default.txt aparc_parcels_nocoreg.mif
echo "generate matrix to get quantitative information on how strongly each atlas region is connected to all others"
echo "generate matrix to get quantitative information on how strongly each atlas region is connected to all others" >> logfile.txt
date >> logfile.txt
#check how you want to scale (here is by region volume)
mrtransform aparc_parcels_nocoreg.mif -linear diff2struct_mrtrix.txt -inverse aparc_parcels_coreg.mif
#WARNING! if you oriented T1 image on ACPC line before freesurfer segmentation you have to do this:
# cp fs_subj/mri/orig.mgz orig.mgz
# dcm2nii -m n -n Y  orig.mgz
# mrconvert forig.nii.gz orig.nii.gz -datatype uint16le -strides -1,-2,3
# bet orig.nii.gz orig_bet.nii.gz
# mrconvert orig_bet.nii.gz orig_bet.nii.gz -datatype uint16le
# epi_reg --epi=mean_b0_preprocessed.nii.gz --t1=orig.nii.gz --t1brain=orig_bet.nii.gz --out=diff_epi_reg_aparc --noclean -v
# transformconvert diff_epi_reg_aparc.mat mean_b0_preprocessed.nii.gz orig.nii.gz flirt_import diff2aparc_mrtrix.txt
# mrtransform aparc_parcels_nocoreg.mif -linear diff2aparc_mrtrix.txt -inverse aparc_parcels_coreg.mif -force
#
tck2connectome -symmetric -zero_diagonal -scale_invnodevol tracks_1mio.tck -tck_weights_in weights_1mio.csv aparc_parcels_coreg.mif connectome.csv -out_assignment assignments_aparc.csv
#selecting connections between two atlas regions
connectome2tck -nodes 29,19 -exclusive tracks_1mio.tck -tck_weights_in weights_1mio.csv assignments_aparc.csv L_arc_tri
#create a mask of the node regions for overlay purpose
mrcalc aparc_parcels_coreg.mif 29 -eq L_STG.mif
#One more useful hint. If you ever wish to merge two atlas regions, first extract each region
#individually via the mrcalc –eq option, as just explained. Then merge the regions, using e.g.
#mrcalc roi_one.mif roi_two.mif –max merged_roi.mif !
mrcalc aparc_parcels_coreg.mif 17 -eq L_pop.mif
mrcalc aparc_parcels_coreg.mif 18 -eq L_por.mif
mrcalc aparc_parcels_coreg.mif 19 -eq L_ptr.mif
mrcalc  L_pop.mif L_por.mif L_ptr.mif  -max merged_IFG.mif

#how to analyze all the streamlines that emerged from a ROI?
#we'll analyze from left and right thalamus
#connectome2tck -nodes 18,29 tracks_1mio.tck -tck_weights_in weights_1mio.csv assignments_aparc.csv -files per_node bubu


#vedo il connettoma
mrconvert -datatype uint32 apa_parcels_coreg.mif aparc_parcels_coreg_32.mif
mrview aparc_parcels_coreg.mif -connectome.init aparc_parcels_coreg_32.mif -connectome.load connectome.csv

#se da errore fai mrconvert -datatype uint32 hcpmmp1_parcels_coreg.mif hcpmmp1_parcels_coreg_32.mif e rigira

#più anatomico:
label2mesh aparc_parcels_coreg_32.mif aparc_mesh.obj -force

#per stimare exemplar file e vedere il connettoma:
#connectome2tck sift_1mio.tck assignments_hcpmmp1.csv exemplar -files single -exemplars hcpmmp1_parcels_coreg_32.mif
connectome2tck tracks_1mio.tck -tck_weights_in weights_1mio.csv assignments_aparc.csv exemplar -files single -exemplars aparc_parcels_coreg_32.mif -force

#per creare una parcellizzazione ri recon-all che abbia già incluse broca e wernicke usa recon-all -s subjid -ba-labels https://surfer.nmr.mgh.harvard.edu/fswiki/BrodmannAreaMaps



#===================================================
#how to extract FA and MD from each streamline of a track

dwi2tensor dwi_den_unr_preproc.mif tensor.mif -mask mask_den_unr_preproc.mif
tensor2metric tensor.mif -fa fa.mif -adc MD.mif -force
tcksample L_arc_tri19-29.tck fa.mif -stat_tck mean FA_values.csv -force
tcksample L_arc_tri19-29.tck MD.mif -stat_tck mean MD_values.csv -force

#you can also visualize these values on a tractp (e.g. min and max FA in each streamline) with this:
tcksample L_arc_tri19-29.tck fa.mif FA_values.tsf -force
mrview T1_coreg.mif tractography.load L_arc_tri19-29.tck  -tractography.tsf_load FA_values.tsf
#usa poi il file.tsf come color nella trattografia su mrview
