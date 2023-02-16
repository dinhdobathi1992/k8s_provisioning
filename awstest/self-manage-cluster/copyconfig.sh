#!/bin/bash


countdown() {
    start="$(( $(date '+%s') + $1))"
    while [ $start -ge $(date +%s) ]; do
        time="$(( $start - $(date +%s) ))"
        printf '%s\r' "$(date -u -d "@$time" +%H:%M:%S)"
        sleep 0.1
    done
}

string=`terraform output control_plane_ip | head -2 | tail -1 `
ip=`echo $string | awk '{ print substr( $0, 1, length($0)-1 ) }' | sed 's/^.//;s/.$//'`


echo "K8S Cluster Public IP: $ip"

echo "Waiting for Cluster Provision"
countdown 300

echo "Copying config" 
mkdir ~/.kube
scp -i k8s-class.pem ubuntu@$ip:/tmp/config/config.public  ~/.kube/config
