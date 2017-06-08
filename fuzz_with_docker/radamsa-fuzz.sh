#!/bin/sh
#
# $Id$
#
#

while true
do
	radamsa -o fuzz/fuzz-%n -n 100 fuzz/sample-*
	for i in fuzz/fuzz*; do
		cqlsh < "$i"
		test $? -gt 127 && break
		test -f core/* && break
	done
done
