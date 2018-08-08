
###this script should be in the folder scriptsCoNiTi

scriptsFolder=$PWD
cd ..

workDir=$PWD
echo "working folder is " $workDir

cd  $workDir/7_MTPRelaxedPoscarsInConvexHull/vaspRuns/
vaspFolder=$PWD

module purge
module load mpi/openmpi-1.8.5_intel-15.0.2
module switch compiler_intel/15.0.2 compiler_intel/2017
## # Now we are going to generate POSCARs files for each structure mlp chose:
## $workDir/mlpFolder/mlp convert-cfg diff.cfg POSCAR --output-format=vasp-poscar


################################################################################
# Compiling code for fixing POSCARs generated by ./mlp to make suitable for
# VASP, as it will not accept zero-occupation.
# Remember that in 1_scfVasp folder, the POSCARs were generated by makeStr.py
# (using the prepareForVASP.py code) without zero concentrations, so we had no
# problems.
################################################################################
cd $scriptsFolder
g++ fixing_POSCARs.cpp # the output is a.out



################################################################################
# Sending to VASP
################################################################################
## cd  $workDir
## mkdir 5_afterActiveLearning
## cd 5_afterActiveLearning/

## mkdir justPOSCARs/
## mkdir runVasp/

## mv  $workDir/2_myTraining/POSCAR*  justPOSCARs/
##echo "POSCARs relocated ..."

## cd justPOSCARs/

cd $vaspFolder
ls > folderNames

# in the first line, the name "foldersToCreate" was also displayed, so
# I cut the first line:
##sed -i '1d' foldersToCreate
sed -i '$ d' folderNames  # to remove the last line

while IFS= read -r line
do
  ## echo "file = " $line
  ## mkdir ../runVasp/$line/
  ## cp $line                      ../runVasp/$line/POSCAR

  cd $vaspFolder/$line

  cp $scriptsFolder/CARS/*                 .   # << copy INCAR and PRECALC.
  cp $scriptsFolder/getKPoints             .
  cp $scriptsFolder/vaspPotcars/Co/POTCAR  Co_POTCAR
  cp $scriptsFolder/vaspPotcars/W/POTCAR  W_POTCAR
  cp $scriptsFolder/vaspPotcars/Al/POTCAR  Al_POTCAR

  # a.out is compiled from fixingPOSCARs.cpp to fix the POSCAR and get a POTCAR.
  cp $scriptsFolder/a.out                  .

  ./getKPoints
  cp POSCAR backupPOSCAR
  ./a.out  # fix the POSCAR (without 0 occupation)
           # and get a suitable POTCAR for VASP
   mv fixedPOSCAR POSCAR
   pwd

cat > "jobVasp" << FIN
#!/bin/bash
####################################
#SBATCH --time=03:00:00   # walltime
#SBATCH --ntasks=1   # number of processor cores (i.e. tasks)
#SBATCH --nodes=1   # number of nodes
#SBATCH --mem-per-cpu=3072M   # memory per CPU core
#SBATCH -J "v$line"   # job name
#SBATCH --mail-user=carlos.leon.chinchay@gmail.com   # email address
#SBATCH --mail-type=FAIL
#SBATCH -p physics
# Set the max number of threads to use for programs using OpenMP. Should be <= ppn. Does nothing if the program doesn't use OpenMP.
export OMP_NUM_THREADS=$SLURM_CPUS_ON_NODE
# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE
module purge
module load compiler_intel/13.0.1
module load gdb/7.9.1
module load compiler_gnu/4.9.2
module load mpi/openmpi-1.8.4_gnu-4.9.2
/fslhome/glh43/bin/vasp54s
####################################
FIN

done <"folderNames"

cd $vaspFolder
## file=$workDir/5_afterActiveLearning/justPOSCARs/foldersToCreate
while IFS= read -r line
do
   echo "folder = " $line
   cd $vaspFolder/$line
   sbatch jobVasp
done <"folderNames"


##
