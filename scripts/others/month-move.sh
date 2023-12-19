#!/bin/bash
echo begin

DIR='/media/Data/Sync/Transfer/Adi-23'

find $DIR -maxdepth 1 -type f -iname '*.jp*g' -o -iname '*.png' |
while read -r photo
do
    month=$(exiv2 -q pr "$photo" | busybox awk -v c=1 -F '[: ]' '/timestamp.*[0-9]{4}:[0-9]{2}:[0-9]{2}/{print $5"_"$6; c=0} END{exit c}') ||
    month=$(busybox stat -c %y "$photo" | busybox awk -v c=1 -F '[- ]' '/[0-9]{4}-[0-9]{2}-[0-9]{2}/{print $1"_"$2; c=0} END{exit c}') ||
    { echo "Couldn't find month for $photo" >&2; continue; }

    mkdir -p "$DIR/$month"
    mv -n "$photo" "$DIR/$month/"
done

echo Done.
