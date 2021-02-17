#!/bin/bash

Red=$'\e[1;31m'
Green=$'\e[1;32m'
Yellow=$'\e[1;33m'
Blue=$'\e[1;34m'
Magenta=$'\e[1;35m'
NC=$'\e[m'

TMP_FOLDER="/READY_NAS/Media/Pictures-Modified-20200212/"
LOG_FILE="./log-$(date +%Y-%M-%d%t%H:%M:%S).log"
DEBUG=0

# Global Variables
NEW_FILE_NAME=""
EXIF_TIMESTAMP=""
isImage=0
isVideo=0

function show_usage (){
    echo -e "Usage: $0 [options [parameters]]\n"
    echo -e "\n"
    echo -e "Options:\n"
    echo -e "-i|--input [input_path], Input directory to scan pictures\n"
    echo -e "-o|--output [output_path], Output directory to copy the pictures\n"
    echo -e "-h|--help, Print help\n"

    return 0
}


function parseDateTimeMetaData () {

    YEAR="${1:0:4}"
    MONTH="${1:5:2}"
    DAY="${1:8:2}"
    HOUR="${1:11:2}"
    MIN="${1:14:2}"
	SEC="${1:17:2}"
    MSEC="${1:20:3}"

    if [ -n "$MSEC" ]; then
        NEW_FILE_NAME="$YEAR$MONTH$DAY-$HOUR:$MIN:$SEC.$MSEC"
        EXIF_TIMESTAMP="$YEAR:$MONTH:$DAY $HOUR:$MIN:$SEC:$MSEC"
    else
        NEW_FILE_NAME="$YEAR$MONTH$DAY-$HOUR:$MIN:$SEC"
        EXIF_TIMESTAMP="$YEAR:$MONTH:$DAY $HOUR:$MIN:$SEC"
    fi

    return 0
}

function isWhatsappMediaFile (){

	if [[ "${1}" =~ VID-[0-9]{8}-WA[0-9]{4} ]]; then
    	printf "%s\n" "${1} is a Whatsapp Video"
	elif [[ "${1}" =~ IMG-[0-9]{8}-WA[0-9]{4} ]]; then
    	printf "%s\n" "${1} is a Whatsapp Image"
    else
        return 0
    fi

    YEAR="${1:4:4}"
	MONTH="${1:8:2}"
	DAY="${1:10:2}"
	INDEX="${1:15:4}"
    NEW_FILE_NAME="$YEAR$MONTH$DAY-$INDEX"
    EXIF_TIMESTAMP="$YEAR:$MONTH:$DAY 00:00:00"
    return 1
}

function isScreenshot (){
	if [[ "${1}" =~ Screenshot-[0-9]{8}-[0-9]{6} ]]; then
    	printf "%s\n" "${1} is a Screenshot"
    else
        return 0
    fi

    YEAR="${1:4:4}"
	MONTH="${1:8:2}"
	DAY="${1:10:2}"
    HOUR="${1:13:2}"
	MIN="${1:16:2}"
	SEC="${1:19:2}"

    NEW_FILE_NAME="$YEAR-$MONTH-$DAY-$HOUR:$MIN:$SEC"
    EXIF_TIMESTAMP="$YEAR:$MONTH:$DAY $HOUR:$MIN:$SEC"

    return 1
}
# Parsing arguments
while [ ! -z "$1" ]; do
    case "$1" in
        -h|--help)
            show_usage
            ;;
        -i|--input)
            shift
            INPUT="$1"
    	    #if [ -d "$INPUT" ]; then
	        #	INPUT="$INPUT*"
	        #fi
            INPUT=$(readlink -f "$INPUT")
	        echo "Input Path= $INPUT"
            ;;
        -o|--output)
            shift
            OUTPUT="$1"
            OUTPUT=$(readlink -f "$OUTPUT")
	        echo "Output Path= $OUTPUT"
            ;;
        *)
            echo "Incorrect input provided"
            show_usage
    esac
shift
done

# Check args are not empty
if [ -z "$INPUT" ]; then
	echo -e "Input file cannot be empty \n. Exiting..."
	exit 1
fi
if [ -z "$OUTPUT" ]; then
    echo -e "Output file cannot be empty \n. Exiting..."
    exit 1
fi

# Loop accross all the pictures
for filename in $(find "$INPUT/" -type f); do

    #echo "Filename = $filename"
    if [ ! -f "$filename" ]; then
        printf "$Red%s$NC\n" "[WARNING]: $filename is not a file. Skipped"
        continue
    fi

    shortName=${filename##*/}
	fullpath=$(readlink -f "$filename")
	dirName=$(dirname "$fullpath")
    extension=$(echo ${filename##*.} | tr [:upper:] [:lower:])
    if [ "$DEBUG" == 1  ]; then
		echo "Name = $shortName"
		echo "Ext = $extension"
        echo "Fullpath = $fullpath"
	fi

    # Pictures only
    if $(file "$filename" | grep -qE 'image|bitmap'); then
		printf "$Magenta%s$NC\n" "File $shortName is an image"
		isImage=1
        isVideo=0
        createdTime="$(exiftool "$fullpath" | grep -oP '(?<=Date/Time Original              : ).*' | tail -n1)"
    elif $(file "$filename" | grep -qE 'Media'); then
		printf "$Magenta%s$NC\n" "File $shortName is a video"
        isVideo=1
        isImage=0
        createdTime="$(exiftool "$fullpath" | grep -oP '(?<=Media Create Date               : ).*' | tail -n1)"
    else
		printf "$Yellow%s$NC\n" "Not an image nor a video. Skipping..."
        continue
    fi
#        echo "Date Time = $createdTime"

		if [ -z "$createdTime" ]; then
#           createdTime="$(exiftool "$fullpath" | grep -oP '(?<=File Modification Date/Time     : ).*' | tail -n1)"
#           echo "New Date Time = $createdTime"

            printf "$Yellow%s$NC\n" "[WARNING]: No metadata available for $shortName"

            isWhatsappMediaFile "$shortName"
            if [ "$?" == 0 ]; then
                printf "$Blue%s$NC\n" "[INFO]: Not Whatsapp media"
                isScreenshot "$shortName"
                if [ "$?" == 0 ]; then
				    printf "$Red%s$NC\n" "[ERROR]: No information found for file $shortName. Skipping..."
                    continue;
                fi
            fi

            echo "New Name = $NEW_FILE_NAME"
		else
            parseDateTimeMetaData "$createdTime"

            #printf "$Yellow%s$NC\n" "[WARNING]: New File Name = $NEW_FILE_NAME"
        fi

        newFile="$OUTPUT/$NEW_FILE_NAME.$extension"

        # Copying new file
        if ! [ -f "$newFile" ]; then
            printf "$Green%s$NC\n" "Copying < $fullpath > to < $newFile >"
            cp "$fullpath" "$newFile"
            exiftool "-alldates=$EXIF_TIMESTAMP" -overwrite_original "$newFile"
            exiftool "-FileModifyDate=$EXIF_TIMESTAMP" -overwrite_original "$newFile"
        else
            printf "$Blue%s$NC\n" "[INFO] File < $newFile > already exist !"
        fi
#    fi
done

