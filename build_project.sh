#!/bin/bash


oc apply -f httpd/httpd_project.yaml
oc apply -n httpd -f httpd/httpd_is.yaml
oc apply -n httpd -f httpd/httpd_bc.yaml
oc apply -n httpd -f httpd/httpd_deploy.yaml
oc apply -n httpd -f httpd/httpd_service.yaml
oc apply -n httpd -f httpd/httpd_gateway.yaml
oc apply -n httpd -f httpd/httpd_virtual_service.yaml
oc apply -n istio-system -f istio-system/route.yaml
