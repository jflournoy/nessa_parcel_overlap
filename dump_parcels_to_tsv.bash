#!/bin/bash

files=( $( find Parcellation_Files/Parcellations_in_Volume/ -regex '.*nii\(\.gz\)*' | sort ) )

if [ -f "file_list.csv" ]; then
	rm file_list.csv
fi

dumpinputfiles=( )
dumpoutputfiles=( )
for i in "${!files[@]}"; do
	file="${files[$i]}"
	printf "###\n\n%s:\n" ${file}
	dims=( $( 3dinfo "${file}" |grep " mm"|awk ' { print $9 } ' ) )
	istwo=true
	for dim in ${dims[@]}; do
		dimnum=$( printf "%0.0f\n" ${dim} )
		if [ "${dimnum}" != "2" ]; then
			istwo=false
		fi
	done
	new2mmname="parcels_2mm/$( basename ${file} )"
	if ${istwo}; then
		printf "Dimensions all 2 mm\n"
		cp ${file} ${new2mmname}
		dumpinput=${new2mmname}
	else
		printf "Dimensions not all 2 mm!\n"
		if ! [ -f "${new2mmname%.nii*}.2mm.nii.gz" ]; then
			printf "Resampling...\n"
			3dresample -master MNI152_T1_2mm_brain.nii.gz -prefix ${new2mmname%.nii*}.2mm.nii.gz -input ${file}
		else
			printf "Resampled file already exists.\n"
		fi
		dumpinput="${new2mmname%.nii*}.2mm.nii.gz"
	fi
	dumpoutput=${dumpinput%.nii*}.tsv
	printf "Dumping\n"
	if ! [ -f "${dumpoutput}" ]; then
		3dmaskdump -nozero -o ${dumpoutput} ${dumpinput}
	fi
	dumpinputfiles+=("${dumpinput}")
	dumpoutputfiles+=("${dumpoutput}")
done

3dmaskdump -nozero -o all_parcels.tsv ${dumpinputfiles[@]}

printf "All single-parcelation output files:\n"
printf "%s\n" ${dumpoutputfiles[@]} | tee file_list.csv
