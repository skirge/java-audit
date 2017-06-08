#!/bin/bash

MYDIR=/oss/sec/serianalyzer
MYJAR=$MYDIR/target/serianalyzer-1.1.0-jar-with-dependencies.jar
WHITELIST="-w $MYDIR/falsepositive -w $MYDIR/baseline -w $MYDIR/statics"
JRE=/usr/lib/jvm/java-8-oracle/jre/lib/rt.jar

set -e

TARGETS=$@

echo "[*] TARGETS is $TARGETS"

java -Xmx13G -cp "$MYJAR" serianalyzer.Main $WHITELIST -v -d -o state $JRE $TARGETS 2>&1 | tee serianalyzer.log
