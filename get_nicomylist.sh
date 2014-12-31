#!/bin/bash

USAGE="Usage: $CMDNAMD [MYLIST_NO[,...]]"

#arg count=1
if [ ${#@} -ne 1 ] ; then
	echo "Invalid Arg."
	echo ${USAGE}
	exit 1
fi

#mylist no. from stdin
if [ -p /dev/stdin ] ; then
	mlist=$(cat -)
else
	mlist=(`echo $@ | tr -s ',' ' '`)
fi

for m in "${mlist[@]}" ;
do
	curl -s "http://www.nicovideo.jp/mylist/${m}" | awk -F ',' '{for(i=1; i<=NF; i++){print $(i);}}' | egrep '"watch_id":"(sm|nm|)[0-9]+"' | sed -e 's/\"watch_id\":\"\(\(sm\|nm\|\)[0-9]\+\)\".*/\1/g'
 
done
exit 0
