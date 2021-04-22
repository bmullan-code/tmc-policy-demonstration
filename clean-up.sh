#!/bin/bash
kubectl delete svc/node-app
kubectl delete svc/node-app1 -n app1
kubectl delete svc/node-app2 -n app2

kubectl delete pod/node-app -n app1
kubectl delete pod/node-app -n app2
kubectl delete pod/node-app