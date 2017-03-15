#!/usr/bin/env bash

timestamp=`date +%Y-%m-%d`
echo "Updating the list of modules on $timestamp "
source $HOME/.bashrc

function print_usage {
	echo "Usage: $0 --user <user> --password <password> [--pagetitle <page title>] --apiurl <apiurl> [--rootdir <directory where the scripts are>]"
	echo "  user should be the user to use on the wiki"
	echo "  password should be the password to use for that user"
	echo "  pagetitle is the page title (default: Modules)"
	echo "  apiurl is the api url to use (typically https://<hostname>/mediawiki/api.php"
}

TEMP=$(getopt -o u:p:t:a: --longoptions user:,password:,pagetitle:,apiurl:,rootdir: -n $0 -- "$@")
eval set -- "$TEMP"

PAGE="Modules"
USERNAME=""
USERPASS=""
WIKIAPI="https://docs-dev.computecanada.ca/mediawiki/api.php"
ROOT_DIR="/home/wiki_module_bot/modules_scripts"
JQ="/cvmfs/soft.computecanada.ca/nix/var/nix/profiles/16.09/bin/jq"

while true; do
	case "$1" in
		-u|--user)
			USERNAME=$2; shift 2;;
		-p|--password)
			USERPASS=$2; shift 2;;
		-t|--pagetitle)
			PAGE=$2; shift 2;;
		-a|--apiurl)
			WIKIAPI=$2; shift 2;;
		--rootdir)
			ROOT_DIR=$2; shift 2;;
		--) shift; break ;;
		*) echo "Unknown parameter $1"; print_usage; exit 1 ;;
	esac
done

if [[ "$USERNAME" == "" || "$USERPASS" == "" ]]; then print_usage; exit 1; fi

#The very first is to produce a list of software in xml format, then convert it into txt type.
XMLFILE="$ROOT_DIR/cvmfs_modules.xml"
WIKITXTFILE="$ROOT_DIR/cvmfs_modules.txt"
COOKIE_JAR="$ROOT_DIR/wikicj"
MODULES_PY="$ROOT_DIR/modules.py"
MODULES_CFG="$ROOT_DIR/cvmfs-client-dev.cfg"
MODULES_TO_WIKI_XLS="$ROOT_DIR/modules-to-mediawiki.xsl"

#Will store file in wikifile
python "$MODULES_PY" -c "$MODULES_CFG" -o $XMLFILE
xsltproc "$MODULES_TO_WIKI_XLS" "$XMLFILE" > "$WIKITXTFILE"

echo "Logging into $WIKIAPI as $USERNAME..."

#Part 1: Getting the login token
echo "Part 1: Getting the login token ..."
CR=$(curl -S \
	--location \
	--retry 2 \
	--retry-delay 5\
	--cookie $COOKIE_JAR \
	--cookie-jar $COOKIE_JAR \
	--user-agent "Curl Shell Script" \
	--keepalive-time 600 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--request "GET" "${WIKIAPI}?action=query&meta=tokens&type=login&format=json")

echo "$CR" | $JQ .
	
rm login.json
echo "$CR" > login.json
TOKEN=$($JQ --raw-output '.query.tokens.logintoken' login.json)
TOKEN="${TOKEN//\"/}" 

#Remove carriage return!
printf "%s" "$TOKEN" > token.txt
TOKEN=$(cat token.txt | sed 's/\r$//')


if [ "$TOKEN" == "null" ]; then
	echo "Getting a login token failed."
	exit	
else
	echo "Login token is $TOKEN"
	echo "-----"
fi

###############
#Part 2: Authenticating with Mediawiki
echo "Part 2: Authenticating ... "
CR=$(curl -S \
	--location \
	--cookie $COOKIE_JAR \
    --cookie-jar $COOKIE_JAR \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--data-urlencode "username=${USERNAME}" \
	--data-urlencode "password=${USERPASS}" \
	--data-urlencode "rememberMe=1" \
	--data-urlencode "logintoken=${TOKEN}" \
	--data-urlencode "loginreturnurl=http://en.wikipedia.org" \
	--request "POST" "${WIKIAPI}?action=clientlogin&format=json")

echo "$CR" | $JQ .

STATUS=$(echo $CR | $JQ '.clientlogin.status')
if [[ $STATUS == *"PASS"* ]]; then
	echo "Successfully logged in as $USERNAME, STATUS is $STATUS."
	echo "-----"
else
	echo "Unable to login, is logintoken ${TOKEN} correct?"
#	exit
fi

###############
#Part 3: Getting the edit token
echo "Part 3: Fetching the edit token..."
CR=$(curl -S \
	--location \
	--cookie $COOKIE_JAR \
	--cookie-jar $COOKIE_JAR \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--request "POST" "${WIKIAPI}?action=query&meta=tokens&format=json")

echo "$CR" | $JQ .
echo "$CR" > edittoken.json
EDITTOKEN=$($JQ --raw-output '.query.tokens.csrftoken' edittoken.json)
rm edittoken.json

EDITTOKEN="${EDITTOKEN//\"/}" #replace double quote by nothing

#Remove carriage return!
printf "%s" "$EDITTOKEN" > edittoken.txt
EDITTOKEN=$(cat edittoken.txt | sed 's/\r$//')

if [[ $EDITTOKEN == *"+\\"* ]]; then
	echo "Edit token is: $EDITTOKEN"
else
	echo "Edit token not set."
	exit
fi

###############
#Part 3 : Making the edit by posting to the given page
CR=$(curl -S \
	--location \
	--cookie $COOKIE_JAR \
	--cookie-jar $COOKIE_JAR \
	--user-agent "Curl Shell Script" \
	--keepalive-time 60 \
	--header "Accept-Language: en-us" \
	--header "Connection: keep-alive" \
	--compressed \
	--data-urlencode "title=${PAGE}" \
	--data-urlencode text@${WIKITXTFILE} \
	--data-urlencode "token=${EDITTOKEN}" \
	--request "POST" "${WIKIAPI}?action=edit&format=json")
	
echo "$CR" | $JQ .
