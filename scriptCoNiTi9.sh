
###this script should be in the folder scriptsCoNiTi

scriptsFolder=$PWD
cd ..

workDir=$PWD
echo "working folder is " $workDir


cat > "job_TrainingAndRelaxation" << FIN
#!/bin/bash
####################################
####################################
#SBATCH --time=12:00:00   # walltime
#SBATCH --ntasks=8   # number of processor cores (i.e. tasks)
#SBATCH --nodes=1   # number of nodes
#SBATCH --mem-per-cpu=4096M   # memory per CPU core
#SBATCH -J "job_TrainingAndRelaxation"   # job name
#SBATCH --mail-user=carlos.leon.chinchay@gmail.com   # email address
#SBATCH --mail-type=FAIL

# LOAD MODULES, INSERT CODE, AND RUN YOUR PROGRAMS HERE
module purge
module load mpi/openmpi-1.8.5_intel-15.0.2
module switch compiler_intel/15.0.2 compiler_intel/2017

####################################
####################################
####################################
####################################


################################################################################
# Compiling code for fixing diff.cfg that WILL BE generated by ./mlp to make
# suitable for VASP, as it will not accept zero-concentrations.
################################################################################
cd $scriptsFolder
g++ fixing_cfgFiles.cpp # the output is a.out


################################################################################
# Generate the diff.cfg files using mlp
# You should ckeck if the previous VASP runnings did well!
################################################################################
cd $workDir/5_afterActiveLearning/runVasp/
runVaspDir=$PWD

rm train2.cfg    #created in previous step.
touch train2.cfg

file="$workDir/5_afterActiveLearning/justPOSCARs/foldersToCreate"

while IFS= read -r line
do
  echo "file = " $line
  cd ${runVaspDir}/$line/
  ###cd $runVaspDir/$line/

  ### creating diff.cfg using mlp:
  $workDir/mlpFolder/mlp convert-cfg OUTCAR diff.cfg --input-format=vasp-outcar >> outcar.txt

  ### a.out was compiled from fixing_cfgFiles.cpp to fix the diff.cfg file
  cp $scriptsFolder/a.out  .

  ### fixing diff.cfg file:
  cp diff.cfg  backup_diff.cfg
  ./a.out  # the fixed file is in diff_fixed.cfg
  mv diff_fixed.cfg  diff.cfg

  ### concatenating *.cfg files:
  cd $runVaspDir
  cat train2.cfg  $runVaspDir/$line/diff.cfg  >  tempFile.txt
  mv tempFile.txt train2.cfg
  echo $line

done <"$file"
echo "concatenated."


################################################################################
# TRAINING !!!
################################################################################
cd $runVaspDir
cp train2.cfg  $workDir/2_myTraining/train.cfg
cd $workDir/2_myTraining/

mpirun -n 8 $workDir/mlpFolder/mlp train pot.mtp train.cfg > training.txt
mv Trained.mtp_ pot.mtp
$workDir/mlpFolder/mlp calc-grade pot.mtp train.cfg train.cfg temp1.cfg
echo "trained."


################################################################################
# RELAXATION
################################################################################
cd  $workDir/4_toRelax/

cp  $workDir/2_myTraining/state.mvs .
cp  $workDir/2_myTraining/pot.mtp   .
rm  select* # created by ./mlp in previous relaxation.

## files to_relax.cfg and relax.ini exist already there from in previous steps.

rm select*
mpirun -n 8 $workDir/mlpFolder/mlp relax relax.ini --cfg-filename=to-relax.cfg
cat selected.cfg_0   selected.cfg_1   selected.cfg_2   selected.cfg_3   selected.cfg_4   selected.cfg_5   selected.cfg_6   selected.cfg_7 > selected.cfg
echo "relaxed"

###

####################################
FIN


##sbatch job_TrainingAndRelaxation

