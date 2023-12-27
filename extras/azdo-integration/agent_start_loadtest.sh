#!/bin/bash
start_performance_test() {
    cd $(System.ArtifactsDirectory)/$(Release.PrimaryArtifactSourceAlias)/extras/jmeter
    #SERVER_URL=$(kubectl get service frontend -n $(staging_namespace) | awk '{print $4}')
    echo "Pointing to $SERVER_URL "
    # using default for now
    /home/daniel_braaf/jmeter/apache-jmeter-5.5/bin/jmeter -SERVER_URL=$SERVER_URL -JVUCount=10 -JLoopCount=30 -n -t Test_Banking_Process.jmx -l testreport.jtl
}

start_timestamp=$(date '+%F %H:%M:00')
echo $start_timestamp
echo "##vso[task.setvariable variable=start_timestamp]$start_timestamp"
start_performance_test
stop_timestamp=$(date '+%F %H:%M:00')
echo $stop_timestamp
echo "##vso[task.setvariable variable=stop_timestamp]$stop_timestamp"
