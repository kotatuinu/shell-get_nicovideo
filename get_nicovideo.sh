#!/bin/bash

NICO_LOGIN_URL='https://secure.nicovideo.jp/secure/login?site=niconico'
NICO_TOP_URL='http://www.nicovideo.jp/'
NICO_MOVIE_URL='http://www.nicovideo.jp/watch/'
#NICO_MOVIEINFO_URL='http://flapi.nicovideo.jp/api/getflv?v='
NICO_MOVIEINFO_URL='http://flapi.nicovideo.jp/api/getflv'
NICO_LOGIN='<a href="http://www.nicovideo.jp/login"><span>ログイン</span></a>'
USAGE="Usage: $CMDNAME -u USERID -p PASSWORD [MOVIE_NO[,...]]"

#check arguments

#-u uid
#-p password
while getopts u:p: OPT
do
	case $OPT in
	"u" ) uid="${OPTARG}" ;;
	"p" ) passwd="${OPTARG}" ;;
	*   ) echo ${USAGE}
		exit 1 ;;
	esac
done

if [ "${uid}" = "" -o "${passwd}" = "" ] ; then
	echo ${USAGE}
	exit 1
fi

shift `expr $OPTIND - 1`

#movie no from stdin
if [ -p /dev/stdin ] ; then
	mlist=(`cat -`)
else
	mlist=(`echo $@ | tr -s ',' ' '`)
fi
if [ ${#mlist[@]} -eq 0 ] ; then
	echo "no entries."
	exit 1
fi

#login
trap "rm /tmp/tmp_getnico.$$; rm /tmp/tmp_getnico2.$$; exit 1" 1 2 3 15
curl -s -F 'next_url=' -F 'show_button_facebook=0' -F 'show_button_twitter=0' -F 'nolinks=0' -F '_use_valid_error_code=0' -F "mail_tel=${uid}" -F "password=${passwd}" -c /tmp/tmp_getnico.$$ "${NICO_LOGIN_URL}" > /dev/null 2>&1


tpage=`curl -s -b /tmp/tmp_getnico.$$ ${NICO_TOP_URL} | grep "${NICO_LOGIN}" | wc -l`
if [ ${tpage} -ne 0 ] ; then
	echo "login error"
	exit 1
fi

#get movie loop
for movieno in "${mlist[@]}" ;
do
	#move movie page
	curl -s -b /tmp/tmp_getnico.$$ -c /tmp/tmp_getnico2.$$ "${NICO_MOVIE_URL}${movieno}" > /dev/null 2>&1

	#get movie info
	url=`curl -s -b /tmp/tmp_getnico2.$$ -F "v=${movieno}" ${NICO_MOVIEINFO_URL} | awk -F "&" '{for(i=1; i<=NF; i++){print $i}}' | grep "url=" | cut -c 5- | perl -pe 's/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;'`

	isUrl=`echo ${url} | egrep -e "^http://" | wc -l`
	if [ $isUrl -ne 1 ] ; then
		echo "WARN:fail get movie info. ${movieno}"
		continue
	fi 

	#get movie file
	curl -s -b /tmp/tmp_getnico2.$$ $url -o ${movieno}.mp4
	if [ ! -s ${movieno}.mp4 ] ; then
		echo "WARN:fail get movie file. ${movieno}"
		continue
	fi
	if [ "`head -1 ${movieno}.mp4`" = "403 Forbidden" ] ; then
		rm ${movieno}.mp4
		echo "403 Forbidden. ${movieno}"
		continue
	fi

	echo "${movieno} OK."
done
exit 0

