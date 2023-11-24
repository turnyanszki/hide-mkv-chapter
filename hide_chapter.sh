#!/bin/bash
set -e

file_directory='.'
chapter_length=100

function time_to_seconds() {
    local time=$1
    local hours=$(echo "$time" | cut -d':' -f1)
    local minutes=$(echo "$time" | cut -d':' -f2)
    local seconds=$(echo "$time" | cut -d':' -f3 | awk -F'.' '{print $1}')
    local milliseconds=$(echo "$time" | awk -F'.' '{print $2}')

    echo $((10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds))
}

while getopts ':d:l:h' opt; do
  case "$opt" in
    d)
      file_directory="${OPTARG}"
      ;;

    l)
      chapter_length="${OPTARG}"
      ;;

    h)
      echo "Usage: $(basename $0) -d <directory> -l <chapter_length>"
      exit 0
      ;;

    :)
      echo -e "option requires an argument."
	  echo "Usage: $(basename $0) -d <directory> -l <chapter_length>"
      exit 1
      ;;

    ?)
      echo -e "Invalid command option."
	  echo "Usage: $(basename $0) -d <directory> -l <chapter_length>"
      exit 1
      ;;
  esac
done
shift "$((OPTIND-1))" 

echo $file_directory
echo $chapter_length

min_time_range=$((chapter_length -1))
max_time_range=$((chapter_length +1))

mkdir -p chapters
for file in $file_directory/*.mkv; do
    if [ -f "$file" ]; then
        mkvextract "$file" chapters chapters/"$file".xml
    fi
done

function time_to_seconds() {
    local time=$1
    local hours=$(echo "$time" | cut -d':' -f1)
    local minutes=$(echo "$time" | cut -d':' -f2)
    local seconds=$(echo "$time" | cut -d':' -f3 | awk -f'.' '{print $1}')
    local milliseconds=$(echo "$time" | awk -f'.' '{print $2}')

    echo $((10#$hours * 3600 + 10#$minutes * 60 + 10#$seconds))
}

for file in $file_directory/chapters/*.xml; do
    if [ -f "$file" ]; then
        xml_file=$file
        i=0
        while ifs= read -r line; do
            if [[ $line =~ "<chaptertimestart>" ]]; then
                start_time=$(echo "$line" | awk -f'[><]' '/<chaptertimestart>/ {print $3}' | tr -d '\n ')
                end_times=$(sed -n "/<chaptertimeend>/,/<\/chaptertimeend>/s/.*<chaptertimeend>\(.*\)<\/chaptertimeend>.*/\1/p" "$xml_file")
                readarray -t end_times_array <<<"$end_times"
                start_seconds=$(time_to_seconds "$start_time")
                end_seconds=$(time_to_seconds "${end_times_array[i]}")
                time_difference=$((end_seconds - start_seconds))
                if ((min_time_range <= time_difference && time_difference <= max_time_range)); then
                    xmlstarlet ed -u "/chapters/editionentry/chapteratom[chaptertimestart='$start_time']/chapterflaghidden" -v "1" "$xml_file"
                fi
                i=$((i + 1))
            fi
        done <"$xml_file" >"${xml_file}.hidden"
        mv "${xml_file}.hidden" "$xml_file"
    fi
done

for file in $file_directory/*.mkv; do
    if [ -f "$file" ]; then
        mkvpropedit "$file" -c chapters/"$file".xml
    fi
done
