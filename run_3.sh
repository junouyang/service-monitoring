#!/bin/bash

#parameter: hostname port applicationName accessKey version
echo "params: $1 $2 $3 $4 $5"
projectFolder=`pwd`
cmdJava="java -classpath \"$JAVA_HOME/jre/lib/charsets.jar:$JAVA_HOME/jre/lib/deploy.jar:$JAVA_HOME/jre/lib/ext/cldrdata.jar:$JAVA_HOME/jre/lib/ext/dnsns.jar:$JAVA_HOME/jre/lib/ext/jaccess.jar:$JAVA_HOME/jre/lib/ext/jfxrt.jar:$JAVA_HOME/jre/lib/ext/localedata.jar:$JAVA_HOME/jre/lib/ext/nashorn.jar:$JAVA_HOME/jre/lib/ext/sunec.jar:$JAVA_HOME/jre/lib/ext/sunjce_provider.jar:$JAVA_HOME/jre/lib/ext/sunpkcs11.jar:$JAVA_HOME/jre/lib/ext/zipfs.jar:$JAVA_HOME/jre/lib/javaws.jar:$JAVA_HOME/jre/lib/jce.jar:$JAVA_HOME/jre/lib/jfr.jar:$JAVA_HOME/jre/lib/jfxswt.jar:$JAVA_HOME/jre/lib/jsse.jar:$JAVA_HOME/jre/lib/management-agent.jar:$JAVA_HOME/jre/lib/plugin.jar:$JAVA_HOME/jre/lib/resources.jar:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/ant-javafx.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/javafx-mx.jar:$JAVA_HOME/lib/jconsole.jar:$JAVA_HOME/lib/packager.jar:$JAVA_HOME/lib/sa-jdi.jar:$JAVA_HOME/lib/tools.jar:$projectFolder/out/production/service-monitoring:$projectFolder/lib/jetty-all-9.0.4.v20130625.jar:$projectFolder/lib/commons-io-2.5.jar:$projectFolder/lib/javax.servlet-api-3.0.1.jar:$projectFolder/lib/mockito-all-1.10.19.jar:$projectFolder/lib/commons-lang3-3.5.jar"

cmd="java -classpath \"$JAVA_HOME/jre/lib/charsets.jar:$JAVA_HOME/jre/lib/deploy.jar:$JAVA_HOME/jre/lib/ext/cldrdata.jar:$JAVA_HOME/jre/lib/ext/dnsns.jar:$JAVA_HOME/jre/lib/ext/jaccess.jar:$JAVA_HOME/jre/lib/ext/jfxrt.jar:$JAVA_HOME/jre/lib/ext/localedata.jar:$JAVA_HOME/jre/lib/ext/nashorn.jar:$JAVA_HOME/jre/lib/ext/sunec.jar:$JAVA_HOME/jre/lib/ext/sunjce_provider.jar:$JAVA_HOME/jre/lib/ext/sunpkcs11.jar:$JAVA_HOME/jre/lib/ext/zipfs.jar:$JAVA_HOME/jre/lib/javaws.jar:$JAVA_HOME/jre/lib/jce.jar:$JAVA_HOME/jre/lib/jfr.jar:$JAVA_HOME/jre/lib/jfxswt.jar:$JAVA_HOME/jre/lib/jsse.jar:$JAVA_HOME/jre/lib/management-agent.jar:$JAVA_HOME/jre/lib/plugin.jar:$JAVA_HOME/jre/lib/resources.jar:$JAVA_HOME/jre/lib/rt.jar:$JAVA_HOME/lib/ant-javafx.jar:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/javafx-mx.jar:$JAVA_HOME/lib/jconsole.jar:$JAVA_HOME/lib/packager.jar:$JAVA_HOME/lib/sa-jdi.jar:$JAVA_HOME/lib/tools.jar:$projectFolder/out/production/service-monitoring:$projectFolder/lib/jetty-all-9.0.4.v20130625.jar:$projectFolder/lib/commons-io-2.5.jar:$projectFolder/lib/javax.servlet-api-3.0.1.jar:$projectFolder/lib/mockito-all-1.10.19.jar:$projectFolder/lib/commons-lang3-3.5.jar\" \
-Dappdynamics.controller.hostName=$1 \
-Dappdynamics.controller.port=$2 \
-Dappdynamics.controller.ssl.enabled=false \
-Dappdynamics.agent.applicationName=$3 \
-Dappdynamics.agent.accountAccessKey=$4 \
-javaagent:$projectFolder/lib/javaagent/$5/javaagent.jar"

logFolder="logs/$5/"
service1="web"
service2="bookservice"
service3="database"
mkdir $logFolder
echo $logFolder

$cmd -Dappdynamics.agent.tierName=$service3 -Dappdynamics.agent.nodeName=$service3-node -Dappdynamics.agent.applicationName=$3-downstream BackendService $service3 8989 last-backend:8991 last-backend-1:8992 \
| tee $logFolder/backend-8989.log &
$cmd -Dappdynamics.agent.tierName=$service3-1 -Dappdynamics.agent.nodeName=$service3-node-1 -Dappdynamics.agent.applicationName=$3-downstream BackendService $service3-1 8990 last-backend:8991 last-backend-1:8992 \
| tee $logFolder/backend-8990.log &
$cmd -Dappdynamics.agent.tierName=$service2 -Dappdynamics.agent.nodeName=$service2-node -Dappdynamics.agent.applicationName=$3-upstream BackendService $service2 8988 $service2-2:8993 $service3:8989 $service3-1:8990 last-backend:8991 last-backend-1:8992 \
| tee $logFolder/backend-8988.log &
$cmd -Dappdynamics.agent.tierName=$service2-2 -Dappdynamics.agent.nodeName=$service2-2-node -Dappdynamics.agent.applicationName=$3-upstream BackendService $service2-2 8993 $service3:8989 $service3-1:8990 last-backend:8991 last-backend-1:8992 &
$cmd -Dappdynamics.agent.tierName=$service2-1 -Dappdynamics.agent.nodeName=$service2-node-1 -Dappdynamics.agent.applicationName=$3-upstream BackendService $service2-1 8987 $serivce2:8988 $service3:8989 $service3-1:8990 last-backend:8991 last-backend-1:8992 \
| tee $logFolder/backend-8987.log &
$cmd -Dappdynamics.agent.tierName=inventory-tier -Dappdynamics.agent.nodeName=inventory-node -Dappdynamics.agent.applicationName=inventory BackendService backend 8986 $service2:8988 $service3:8989 $service3-1:8990 | tee $logFolder/backend-8986.log &
$cmdJava BackendService backend 8985 $service2-1:8987 $service3:8989 $service3-1:8990 | tee $logFolder/backend-8985.log &
$cmdJava BackendService last-backend 8991 | tee $logFolder/backend-8991.log &
$cmdJava BackendService last-backend-1 8992 | tee $logFolder/backend-8992.log &
$cmd -Dappdynamics.agent.tierName=$service1 -Dappdynamics.agent.nodeName=$service1-node -Dappdynamics.agent.applicationName=$3-client TestHelloWorld backend 8985 8986 \
| tee $logFolder/helloworld.log

# |$cmd -Dappdynamics.agent.tierName=$service1 -Dappdynamics.agent.nodeName=$service1-node TestHelloWorld 8988 \
# | tee $logFolder/helloworld.log