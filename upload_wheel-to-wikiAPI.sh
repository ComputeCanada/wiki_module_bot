#!/usr/bin/env bash

timestamp=`date +%Y-%m-%d`
echo "Updating the list of python wheel on $timestamp "
source $HOME/.bashrc

function print_usage {
	echo "Usage: $0 --user <user> --password <password> [--pagetitle <page title>] --version <version> --apiurl <apiurl> [--rootdir <directory where the scripts are>]"
	echo "  user should be the user to use on the wiki"
	echo "  password should be the password to use for that user"
	echo "  pagetitle is the page title (default: Modules)"
	echo "  apiurl is the api url to use (typically https://<hostname>/mediawiki/api.php"
}

TEMP=$(getopt -o u:p:t:v:a: --longoptions user:,password:,pagetitle:,versions:,apiurl:,rootdir: -n $0 -- "$@")
eval set -- "$TEMP"

PAGE="Wheels_"
USERNAME=""
USERPASS=""
WIKIAPI="https://docs-dev.computecanada.ca/mediawiki/api.php"
ROOT_DIR="/home/wiki_module_bot/modules_scripts"
JQ="/cvmfs/soft.computecanada.ca/nix/var/nix/profiles/16.09/bin/jq"
#VERSIONS=2.7

while true; do
	case "$1" in
		-u|--user)
			USERNAME=$2; shift 2;;
		-p|--password)
			USERPASS=$2; shift 2;;
		-t|--pagetitle)
			PAGE=$2; shift 2;;
		-v|--versions)
			VERSIONS=$2; shift 2;;
		-a|--apiurl)
			WIKIAPI=$2; shift 2;;
		--rootdir)
			ROOT_DIR=$2; shift 2;;
		--) shift; break ;;
		*) echo "Unknown parameter $1"; print_usage; exit 1 ;;
	esac
done

if [[ "$USERNAME" == "" || "$USERPASS" == "" ]]; then print_usage; exit 1; fi

#The very first is to produce a list of wheels with avail_wheels.py script; the output is in txt format.
#XMLFILE="$ROOT_DIR/cvmfs_modules.xml"
TXTFILE="$ROOT_DIR/cvmfs_wheels"
COOKIE_JAR="$ROOT_DIR/wikicj"

for VERSION in $VERSIONS
do
PAGENAME=$PAGE$VERSION
WIKITXTFILE=$TXTFILE$VERSION
echo $PAGENAME
#avail_wheels --all_versions --arch generic avx2 --python "$VERSION" --condense --mediawiki --column name version  > "$WIKITXTFILE.new"
#/cvmfs/soft.computecanada.ca/custom/python/envs/avail_wheels/bin/python3 -W ignore /cvmfs/soft.computecanada.ca/custom/python/envs/avail_wheels/avail_wheels.py --all-versions --all-arch --python "$VERSION" --mediawiki --column name version --condense > "$WIKITXTFILE.new"
PIP_CONFIG_FILE=""
/cvmfs/soft.computecanada.ca/custom/python/envs/avail_wheels/bin/python3 /cvmfs/soft.computecanada.ca/custom/python/envs/avail_wheels/avail_wheels.py --all-versions --all-arch --python $VERSION --mediawiki --column name version --condense > "$WIKITXTFILE.new"


#Compare the old wikifile with the new one to see whether any new wheels has been installed
lines_changed=$(diff $WIKITXTFILE $WIKITXTFILE.new | wc -l)
if [[ $lines_changed -ne 0 ]]; then
	mv $WIKITXTFILE.new $WIKITXTFILE
else
	echo "Nothing has changed, not updating the wiki"
#	exit 1
	continue
fi

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
	--data-urlencode "title=${PAGENAME}" \
	--data-urlencode text@${WIKITXTFILE} \
	--data-urlencode "token=${EDITTOKEN}" \
	--request "POST" "${WIKIAPI}?action=edit&format=json")
	
echo "$CR" | $JQ .
done
