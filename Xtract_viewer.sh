#!/bin/bash
# Script to view output of Xtract in fsleyes
# Written by Shaun Warrington 07/2019

Usage() {
    cat << EOF

Usage:
    Xtract_viewer -dir <xtractDir> -str <structuresFile> [options]

    Compulsory arguments:

       -dir <folder>                     Path to Xtract folder
                                         e.g. for subject, /data/subID/Xtract
                                              for atlas, /data/tract_atlases

       -str <file>                       Structures file (can be same as xtract input structures list)

    Optional arguments:

       -sub                              Use this flag to view a single subject's data
                                                          (look's for densityNorm.nii.gz under <dir>/tracts/)
                                         Default is to view a tract atlas (looks for <structure>.nii.gz under <dir>)

       -mip                              Use this flag to view tracts as mips, window of 5 slices, spline interpolation

       -thr <number> <number>            The lower and upper thresholds applied to the tracts for viewing
                                         Default for subject = 0.001 0.1, default for atlas = 0.3 1.0

       -brain                            The brain image to use for the background overlay - must be in the same space as tracts.
                                         Default is the FSL_HCP065_FA map
EOF
    exit 1
}

echo "---"
echo "----"
echo "-----"
echo "------"
echo "-------"
echo "------- Xtract Viewer"
echo "-------"
echo "------"
echo "-----"
echo "----"
echo "---"

[ "$1" = "" ] && Usage

# Set defaults
sub=0
mip=0
thr=""
brain=""

# the colourmap options
cmaps=(blue red green blue-lightblue pink red-yellow cool yellow copper \
 hot hsv coolwarm spring summer winter Oranges)
cL="${#cmaps[@]}" # length of array for colourmap loop control

# Parse command-line arguments
while [ ! -z "$1" ];do
    case "$1" in
	-dir) dir=$2;shift;;
	-str) str=$2;shift;;
	-sub) sub=1;;
  -thr) thr=$2;uthr=$3;shift;shift;;
	-mip) mip=1;;
  -brain) brain=$2;shift;;
	*) echo "Unknown option '$1'";exit 1;;
    esac
    shift
done

# Default threshold values and mip opts
if [ "$thr" == "" ];then
  if [ "$sub" == "1" ]; then
    thr=0.001
    uthr=0.1
  elif [ "$sub" == "0" ]; then
    thr=0.3
    uthr=1.0
  fi
fi

if [ "$brain" == "" ];then
  # the FA atlas
  brain=${FSLDIR}/data/standard/FSL_HCP1065_FA_1mm.nii.gz
fi

# Check compulsory arguments
errflag=0
if [ "$dir" == "" ];then
    echo "Must set compulsory argument '-dir'"
    errflag=1
elif [ ! -d $dir ];then
    echo "Xtract folder $dir not found"
    errflag=1
fi
if [ "$str" == "" ];then
  echo "Must set compulsory argument '-str'"
  errflag=1
elif [ ! -f $str ];then
  echo "Structure file $str not found"
  errflag=1
fi
if [ "$uthr" == "" ];then
  echo "You have set a lower threshold but not an upper threshold. Must set '-thr' using <number> <number>"
  errflag=1
fi
if [ ! -f $brain ];then
  echo "Brain overlay file $brain not found"
  errflag=1
fi
if [ "$errflag" -eq 1 ];then
  echo ""
  echo "Exit without doing anything.."
  exit 1
fi

# build struct array - removing any empty/comment lines
# and check for and remove any file extentions
strlist=()
while read structstring; do
  struct=`echo $structstring | awk '{print $1}'`
  # skip empty lines and lines that start with '#'
  if [ "${struct:0:1}" == "#" ];then
    echo "skip"
  elif [ ! "$struct" == "" ];then
    ss=`echo $struct | sed s/.nii.gz//`
    strlist+=("$ss")
  fi
done < $str


# start the fsleyes command with basic options
cmd="${FSLDIR}/bin/fsleyes $brain -dr 0 `fslstats $brain -r | awk '{print $2}'`"
opts="-dr $thr $uthr"
# Using mip?
if [ "$mip" == "1" ];then
  opts="$opts --overlayType mip --interpolation spline --window 5.0"
fi

# subject or atlas data structure?
if [ "$sub" == "1" ];then
  preT="/tracts"
  postT="/densityNorm.nii.gz"
else
  preT=""
  postT=".nii.gz"
fi

# Now loop and check for left/right tracts to colour the same
# checks for _l and matches any _r
# if no _?, then just move on to next line
i=0
for tract in "${strlist[@]}"
do
  if [ $i -gt $((cL - 1)) ]; then i=0; fi # control colourmap loop
  # check tract exists
  if [ ! -f "${dir}/${preT}/${tract}${postT}" ]; then
    echo "Couldn't find ${tract} image."
    echo "Moving on to the next structure."
    echo "Check ${dir}/${preT}/${tract}${postT} and try again"
  else
    # if you find a left tract, then find the corresponding right tract
    # and colour in the same way
    if [[ $tract == *"_l"* ]];then
      tt=`echo ${tract} | sed s/_l/_r/`
      if [ "`grep ${tt} $str`" != "" ];then
        # append _l and _r to fsleyes command with viewing options
        cmd="$cmd ${dir}/${preT}/${tract}${postT} $opts -cm ${cmaps[i]} -n ${tract} ${dir}/${preT}/${tt}${postT} $opts -cm ${cmaps[i]} -n ${tt}"
      else
        # else, just add the current tract
        cmd="$cmd ${dir}/${preT}/${tract}${postT} $opts -cm ${cmaps[i]} -n ${tract}"
      fi
    elif [[ $tract == *"_r"* ]]  && [[ ! $cmd == *"$tract"* ]] && [[ ! ${strlist[@]} == *"`echo ${tract} | sed s/_r/_l/`"* ]];then
      # if tract name has _r and hasn't been found already
      cmd="$cmd ${dir}/${preT}/${tract}${postT} $opts -cm ${cmaps[i]} -n ${tract}"
    elif [[ $tract != *"_r"*  && $tract != *"_l"* ]];then
      # if tract name doesn't have _l or _r
      cmd="$cmd ${dir}/${preT}/${tract}${postT} $opts -cm ${cmaps[i]} -n ${tract}"
    fi
    ((i++))
  fi
done

#echo $cmd
echo "Launching FSLeyes..."
bash $cmd &
#echo $cmd
