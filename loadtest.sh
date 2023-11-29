
#!/bin/bash
set -x

export NODE_IP=192.168.56.10
export ING_PORT=$(kubectl get svc nginx-ingress-nginx-controller -o jsonpath="{.spec.ports[0].nodePort}")
echo "http://$NODE_IP:$ING_PORT/foo"
echo "http://$NODE_IP:$ING_PORT/bar"
echo "-------------------------------------------------------"
echo "*** HTTP Load testing 100 connections for 30 secs ****"
wrk -c100 -d30s --latency http://$NODE_IP:$ING_PORT/foo
wrk -c100 -d30s --latency http://$NODE_IP:$ING_PORT/bar
echo "-------------------------------------------------------"
echo "*** HTTP Load testing 200 connections for 30 secs ****"
wrk -c200 -d30s --latency http://$NODE_IP:$ING_PORT/foo
wrk -c200 -d30s --latency http://$NODE_IP:$ING_PORT/bar
echo "-------------------------------------------------------"
echo "*** HTTP Load testing 400 connections for 30 secs ****"
wrk -c400 -d30s --latency http://$NODE_IP:$ING_PORT/foo
wrk -c400 -d30s --latency http://$NODE_IP:$ING_PORT/bar

echo "*** HTTP Load testing been completed ****"
echo echo "-------------------------------------------------------"

# using curl
#while true; do curl -s http://localhost:4000/metrics > /dev/null ; done
