#!/bin/bash

#parameter: hostname port applicationName accessKey version
echo "params: $1 $2 $3 $4 $5"
projectFolder=`pwd`
cmd="java -classpath \"$JAVA_HOME/jre/lib/charsets.jar:$JAVA_HOME/jre/lib/deploy.jar:$JAVA_HOME/jre/lib/ext/cldrdata.jar:$JAVA_HOME/jre/lib/ext/dnsns.jar:$JAVA_HOME/jre/lib/ext/jaccess.jar:$JAVA_HOME/jre/lib/ext/jfxrt.jar:$JAVA_HOME/jre/lib/ext/localedata.jar:$JAVA_HOME/jre/lib/ext/nashorn.jar:$JAVA_HOME/jre/lib/ext/sunec.jar:$JAVA_HOME/jre/lib/ext/sunjce_provider.jar:$JAVA_HOME/jre/lib/ext/sunpkcs11.jar:$JAVA_HOME/jre/lib/ext/zipfs.jar:$JAVA_HOME/jre/lib/javaws.jar:$JAVA_HOME/jre/lib/jce.jar:$JAVA_HOME/jre/lib/jfr.jar:$JAVA_HOME/jre/lib/jfxswt.jar:$JAVA_HOME/jre/lib/jsse.jar:$JAVA_HOME/jre/lib/management-agent.jar:$JAVA_HOME/jre/lib/plugin.jar:$JAVA_HOME/jre/lib/resources.jar:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/ant-javafx.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/javafx-mx.jar:$JAVA_HOME/lib/jconsole.jar:$JAVA_HOME/lib/packager.jar:$JAVA_HOME/lib/sa-jdi.jar:$JAVA_HOME/lib/tools.jar:$projectFolder/out/production/service-monitoring:$projectFolder/lib/jetty-all-9.0.4.v20130625.jar:$projectFolder/lib/commons-io-2.5.jar:$projectFolder/lib/javax.servlet-api-3.0.1.jar:$projectFolder/lib/mockito-all-1.10.19.jar:$projectFolder/lib/commons-lang3-3.5.jar\" \
-Dappdynamics.controller.hostName=$1 \
-Dappdynamics.controller.port=$2 \
-Dappdynamics.controller.ssl.enabled=false \
-Dappdynamics.agent.applicationName=$3 \
-javaagent:$projectFolder/lib/javaagent/$5/javaagent.jar"

logFolder="logs/$5/"
service1="web"
service2="bookservice"
service3="database"
mkdir $logFolder
echo $logFolder
accessKey1="76d2b7bf-40c1-4c40-84f0-19f7d27b1cd5"
accessKey2="2c045f8c-94e8-4d1c-a094-eff1c228b303"

$cmd -Dappdynamics.agent.tierName=$service3 -Dappdynamics.agent.nodeName=$service3-node -Dappdynamics.agent.applicationName=$3-downstream -Dappdynamics.agent.accountName=customer2 -Dappdynamics.agent.accountAccessKey=$accessKey2 BackendService $service3 8989 \
| tee $logFolder/backend-8989.log & \
$cmd -Dappdynamics.agent.tierName=$service2 -Dappdynamics.agent.nodeName=$service2-node -Dappdynamics.agent.applicationName=$3-upstream -Dappdynamics.agent.accountName=customer1 -Dappdynamics.agent.accountAccessKey=$accessKey1 BackendService $service2 8988 $service3:8989 \
| tee $logFolder/backend-8988.log & \
$cmd -Dappdynamics.agent.tierName=$service1 -Dappdynamics.agent.nodeName=$service1-node -Dappdynamics.agent.applicationName=$3-client -Dappdynamics.agent.accountName=customer1 -Dappdynamics.agent.accountAccessKey=$accessKey1 TestHelloWorld $service2 8988 \
| tee $logFolder/helloworld.log

# |$cmd -Dappdynamics.agent.tierName=$service1 -Dappdynamics.agent.nodeName=$service1-node TestHelloWorld 8988 \
# | tee $logFolder/helloworld.log