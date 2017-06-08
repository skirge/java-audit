#!/bin/bash

JRE=/usr/lib/jvm/java-8-oracle/jre/lib/rt.jar

set -e

ARTIFACT="$1"
WORKDIR=$(realpath $(pwd))
GRAUDIT_EXCLUDE="-x .idea,*test,*mock*,*Test*,*Mock*,*.json,*.js,antlr,*.war,*.jar,fb.xml,*.asciidoc,*.html"

mkdir -p src
mkdir -p deps-src
mkdir -p deps-jars

if [ ! -d "$ARTIFACT" ]
then
	if [ ! -f "$WORKDIR/pom.xml" ]
	then
		echo mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:get -Dartifact=${ARTIFACT}:pom -DrepoUrl=http://repository.sonatype.org/content/repositories/central -Ddest=${WORKDIR}/pom.xml | tee audit.log
		mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:get -Dartifact=${ARTIFACT}:pom -DrepoUrl=http://repository.sonatype.org/content/repositories/central -Ddest=${WORKDIR}/pom.xml 2>&1 > maven.log
	fi

	echo mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:copy -Dartifact=${ARTIFACT}:jar -DrepoUrl=http://repository.sonatype.org/content/repositories/central -DoutputDirectory=$WORKDIR/jars/ | tee -a audit.log
	mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:copy -Dartifact=${ARTIFACT}:jar -DrepoUrl=http://repository.sonatype.org/content/repositories/central -DoutputDirectory=$WORKDIR/jars/ 2>&1 >> maven.log || true

		echo mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:unpack -Dartifact=${ARTIFACT}:jar:sources -DrepoUrl=http://repository.sonatype.org/content/repositories/central -DoutputDirectory=$WORKDIR/src/main/java | tee -a audit.log 
		mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:unpack -Dartifact=${ARTIFACT}:jar:sources -DrepoUrl=http://repository.sonatype.org/content/repositories/central -DoutputDirectory=$WORKDIR/src/main/java 2>&1 > maven.log || true

	echo ${@:2}

	echo mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:copy-dependencies -DoutputDirectory=$WORKDIR/deps-jars/ -DincludeScope=runtime -DrepoUrl=http://repository.sonatype.org/content/repositories/central ${@:2} | tee -a audit.log
	mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:copy-dependencies -DoutputDirectory=$WORKDIR/deps-jars/ -DincludeScope=runtime -DrepoUrl=http://repository.sonatype.org/content/repositories/central ${@:2} 2>&1 >> maven.log || true

	echo mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:unpack-dependencies -Dclassifier=sources -DoutputDirectory=$WORKDIR/deps-src -DincludeScope=runtime -DrepoUrl=http://repository.sonatype.org/content/repositories/central | tee -a audit.log
	mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:unpack-dependencies -Dclassifier=sources -DoutputDirectory=$WORKDIR/deps-src -DincludeScope=runtime -DrepoUrl=http://repository.sonatype.org/content/repositories/central  ${@:2} 2>&1 >> maven.log || true

	TARGETS="$WORKDIR/jars/*.jar $WORKDIR/deps-jars/*.jar"
else
	TARGETS=$@
fi

echo "[*] TARGETS is $TARGETS"

echo "[*] Running Dependency Check analysis"
echo /opt/dependency-check/bin/dependency-check.sh --project ARTFIFACT -s deps-jars -s jars --enableExperimental --suppression /home/skirge/OT/PEN/dependencycheck-test/dependencycheck/dependency-check-suppressions.xml --hints /home/skirge/OT/PEN/dependencycheck-test/dependencycheck/dependency-check-hints.xml --format ALL | tee -a audit.log
/opt/dependency-check/bin/dependency-check.sh --project $ARTIFACT -s deps-jars -s jars --enableExperimental --suppression /home/skirge/OT/PEN/dependencycheck-test/dependencycheck/dependency-check-suppressions.xml --hints /home/skirge/OT/PEN/dependencycheck-test/dependencycheck/dependency-check-hints.xml --format ALL 2>&1 > dc.log

echo "[*] Running graudit on $ARTIFACT sources" 
echo graudit -B -z -d java $GRAUDIT_EXCLUDE src | tee -a audit.log
graudit -B -z -d java $GRAUDIT_EXCLUDE src 2>&1 > graudit.log || true

echo "[*] Running graudit on dependencies sources" 
echo graudit -B -z -d java $GRAUDIT_EXCLUDE deps-src | tee -a audit.log
graudit -B -z -d java $GRAUDIT_EXCLUDE deps-src 2>&1 > grauditfull.log || true

echo "[*] Running Findbugs analysis on main jar"
echo findbugs -maxHeap 8192 -textui -workHard -xml:withMessages -progress -quiet -bugCategories SECURITY -effort:max -experimental -exclude ~/cfg/fb/exclude.xml -output fb.xml -sourcepath $WORKDIR/src/main/java -auxclasspath $WORKDIR/deps-jars -auxclasspath $JRE -projectName $ARTIFACT $WORKDIR/jars | tee -a audit.log

spotbugs -maxHeap 8192 -textui -workHard -xml:withMessages -progress -quiet -bugCategories SECURITY -effort:max -experimental -exclude ~/cfg/fb/exclude.xml -output fb.xml -sourcepath $WORKDIR/src/main/java -auxclasspath $WORKDIR/deps-jars -auxclasspath $JRE -projectName $ARTIFACT $WORKDIR/jars 2>&1 > fb.log

echo "[*] Running Findbugs analysis on dependencies"
echo findbugs -maxHeap 8192 -textui -workHard -xml:withMessages -progress -quiet -bugCategories SECURITY -effort:max -experimental -exclude ~/cfg/fb/exclude.xml -output fbfull.xml -sourcepath deps-src -sourcepath $WORKDIR/deps-src -auxclasspath $JRE -projectName $ARTIFACT-with-dependencies $WORKDIR/deps-jars |tee -a audit.log

spotbugs -maxHeap 8192 -textui -workHard -xml:withMessages -progress -quiet -bugCategories SECURITY -effort:max -experimental -exclude ~/cfg/fb/exclude.xml -output fbfull.xml -sourcepath deps-src -sourcepath $WORKDIR/deps-src -auxclasspath $JRE -projectName $ARTIFACT-with-dependencies deps-jars 2>&1 > fbfull.log

echo "[*] Running serianalyzer analysis"
echo serianalyzer.sh $TARGETS | tee -a audit.log
serianalyzer.sh $TARGETS

echo "[*] Checking for errors"
egrep "FAILURE|ERROR|FATAL" *.log

