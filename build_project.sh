#!/bin/bash

#Install a service mesh control plane if one doesn't exist
HAS_SMCP=$(oc get -n istio-system smcp | grep -c production-install)
if [ $HAS_SMCP -ne 1 ]; then
    oc apply -n istio-system -f istio-system/service_mesh_control_plane.yaml
else
    echo "Service mesh control plane exists, skipping"
fi

#Handle the Service Mesh Member Roll.
HAS_SMMR=$(oc get -n istio-system smmr | grep -c default)
if [ $HAS_SMMR -ne 1 ]; then
    oc apply -n istio-system -f istio-system/service_mesh_member_roll.yaml
else
    #we have a service mesh member roll, but does it contain the httpd project?
    HAS_HTTPD_PROJECT=$(oc get smmr -o json | jq .items[0].spec.members | grep -c httpd)
    if [ $HAS_HTTPD_PROJECT -ne 1 ]; then
        #httpd project wasn't a member of the service mesh member roll, so add it.
        oc get smmr -o json | jq '.items[0].spec.members += ["httpd"]' | oc apply -n istio-system -f -
    fi
fi


echo "Setting up project and service"
oc apply -f httpd/httpd_project.yaml
oc apply -n httpd -f httpd/httpd_is.yaml
oc apply -n httpd -f httpd/httpd_bc.yaml
oc apply -n httpd -f httpd/httpd_deploy.yaml
oc apply -n httpd -f httpd/httpd_service.yaml


#We need to do the route first so that we can extract the FQDN
echo "Setting up route"
oc apply -n istio-system -f istio-system/route.yaml
#grab the FQDN for later
FQDN=$(oc get route -n istio-system httpd -o json | jq '.spec.host' | sed 's/"//g')

echo "Setting up Gateway and Virtual Service"
oc apply -n httpd -f httpd/httpd_gateway.yaml
#Update the hosts field
oc get -n httpd  gateway httpd-gateway -o json | jq ".spec.servers[0].hosts = [\"$FQDN\"]" | oc apply -n httpd -f -

oc apply -n httpd -f httpd/httpd_virtual_service.yaml
#Update the hosts field
oc get -n httpd vs httpd -o json | jq ".spec.hosts = [\"$FQDN\"]" | oc apply -n httpd -f -


#wait for the project to come up
while [ true ]; do
    STATUS_CODE=$(curl -s -k https://$FQDN/index.html -o /dev/null -w "%{http_code}")
    if [ $STATUS_CODE -eq 200 ]; then
        break;
    fi
    echo "Waiting for project to come up..."
    sleep 5
done
echo "Project is up at https://$FQDN/index.html"
