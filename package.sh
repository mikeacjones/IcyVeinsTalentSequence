#!/bin/sh
rm -rf .release/
mkdir .release
mkdir .release/TalentSequence2
cp *.toc .release/TalentSequence2/
cp *.lua .release/TalentSequence2/
cd .release/ && zip -r TalentSequence2-$(sed '3!d' ../IcyVeinsTalentSequence.toc | awk '{print $3}')-tbc-classic.zip . -x ".*" -x "__MACOSX"
rm -rf "Talent Sequence 2.0"