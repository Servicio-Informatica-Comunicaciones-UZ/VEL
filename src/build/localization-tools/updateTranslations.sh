#!/bin/bash


#This tool updates the i18n strings of the user interface script.
#Always call from the root of the project


scriptName=wizard-setup.sh
projectRootPath=./
localizationDir=./src/mgr/localization
localizationToolsDir=$projectRootPath/src/build/localization-tools/


# To update:
# ISO to UTF. ScriptFile.sh
# bash --dump-po-strings ScriptFile.sh > NewTranslationsFile.pot
# getUniquePOstrings.py DestFile.pot TranslationsFile.pot
# msgmerge --update  --previous --no-wrap  CurrentTranslationsFile.po NewTranslationsFile.pot
# Copy to its language directory and translate new strings
# msgfmt -o CompiledTranslFile.mo TranslationsFile.po 

if [ "$1" == "" -o "$1" == "-h" -o "$1" == "--help"  ]
    then
    echo "Usage:   $localizationToolsDir/updateTranslations [list of lang codes (2 letter)]"
    echo "Example: $localizationToolsDir/updateTranslations en ca"
    exit 0
fi


LNS="$@"


if [ -f "$projectRootPath/$scriptName"  ] 
then
    :
else
    echo "Invoke this from the same directory where $scriptName is located (project root: $projectRootPath)."
    exit 1
fi



iconv --from-code=ISO-8859-1 --to-code=UTF-8 $projectRootPath/$scriptName >/tmp/$scriptName
bash --dump-po-strings /tmp/$scriptName > $localizationDir/$scriptName.pot

rm -f /tmp/$scriptName

$localizationToolsDir/getUniquePOstrings.py $localizationDir/$scriptName.pot /tmp/aux


echo '# Trad File
#
#, fuzzy
msgid ""
msgstr ""
"MIME-Version: 1.0\n"
"Content-Type: text/plain; charset=UTF-8\n"
"Content-Transfer-Encoding: 8bit\n"' > $localizationDir/$scriptName.po

cat /tmp/aux >> $localizationDir/$scriptName.po

rm -f /tmp/aux


files=""
for ln in $LNS
  do
  msgmerge --update  --previous --no-wrap $localizationDir/$ln/$scriptName.po $localizationDir/$scriptName.po

  files="$files $localizationDir/$ln/$scriptName.po"
done

echo "Ficheros a tratar: $files"

gedit $files &
  
echo "Traduzca los cambios y pulse INTRO"
read


for ln in $LNS
  do 
  msgfmt -o $localizationDir/$ln/$scriptName.mo $localizationDir/$ln/$scriptName.po
done
