Usage:
------
To create a list of modules in XML format: 
  python modules.py -c cvmfs-client-dev.cfg -o cvmfs_modules.xml
To convert that XML to wiki code: 
  xsltproc modules-to-mediawiki.xsl cvmfs_modules.xml > cvmfs_modules.txt 

To generate the wiki code (above two commands combined) and upload it to a wiki page:
  ./upload-to-wikiAPI.sh --user <username> --password <password> --pagetitle <page title> --apiurl <api url> --rootdir <directory where the scripts are held>

