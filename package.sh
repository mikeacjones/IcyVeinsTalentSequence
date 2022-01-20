#!/bin/sh
rm -rf .release/
mkdir .release
mkdir .release/IcyVeinsTalentSequence
cp *.toc .release/IcyVeinsTalentSequence/
cp *.lua .release/IcyVeinsTalentSequence/
cd .release/ && zip -r IcyVeinsTalentSequence-$(sed '3!d' ../IcyVeinsTalentSequence.toc | awk '{print $3}')-tbc-classic.zip . -x ".*" -x "__MACOSX"
rm -rf IcyVeinsTalentSequence