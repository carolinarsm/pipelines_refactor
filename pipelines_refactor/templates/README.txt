For the analysis of one subject.

### STRUCTURAL ANALYSIS ###

1) Make an experiment folder for the subject you will be running. This folder will contain configuration files, and output log files (error, standard outputs) will be written here.
2) For each task or condition, make a subfolder in the subject's experiment folder
3) Two configuration files should be copied to the experiment folder and edited accordingly for your experiment options:

        - config_structural_*.cfg	: to setup option to perform dicom to nifti conversion and structural preprocessing  
                                  	  '*' will be 'gradientFM' if using gradient filedmaps,	or 'spinechoFM'	if using spin echo fieldmaps for the anatomical scans preprocessing.
				  	  This file should be put in the experiment folder
        - config_functional.cfg		: to setup options to perform functional preprocessing of task fMRI
					  This file should be put on each task or condition subfolder, and edited accordingly for the task/condition.

4) PBS job files should be in the experiment folder and subfolders, for each step of the preprocessing pipeline.
   These files are called 'pbs_stepname.batch', where 'stepname' should be replaced for the name of the step being performed.
   (Right now, they are done separatedly, but we can make one .batch file to run the full pipeline at once)


For example, generic experiment folder structure would look like:

/SUBJECT_ID					# Subject name or ID, for example SUB001
   |--config_structural_*.cfg			# structural configuration file for anatomical scans
   |--pbs_dcm2nii.batch				# pbs job for DICOM to NIFTI conversion
   |--pbs_preFS.batch				# idem, for PreFreeSurferPipeline
   |--pbs_FS.batch				# idem, for FreeSurferPipeline
   |--pbs_dcm2nii.batch				# idem, for PostFreeSurferPipeline
   /TASK1					# Task name 1 
      |--config_functional_task1.cfg		# functional configuration file for task 1
      |--pbs_volume.batch			# task 1 pbs job for GenericfMRIVolumeProcessing 
      |--pbs_surface.batch			# task 1 pbs job for GenericfMRISurfaceProcessing
   /TASK2					# Task name 2
      |--config_functional_task2.cfg		# functional configuration file	for task 2 
      |--pbs_volume.batch			# task 2 pbs job for GenericfMRIVolumeProcessing
      |--pbs_surface.batch			# task 2 pbs job for GenericfMRISurfaceProcessing
   /TASK3					# Task name 3
      |--config_functional_task3.cfg		# functional configuration file	for task 3
      |--pbs_volume.batch			# task 3 pbs job for GenericfMRIVolumeProcessing
      |--pbs_surface.batch			# task 3 pbs job for GenericfMRISurfaceProcessing
....
....
....




(TO DO: Several experiments can be generated with a script) 


### FUNCTIONAL ANALYSIS ###

To check number of volumes in 4D NIFTI (FSL): fslnvols filename.nii.gz --> to modify fsf templates with a script

To do ....
