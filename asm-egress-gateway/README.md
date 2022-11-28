# Enable STRICT mTLS
```kubectl apply -f enable-strict-mtls.yaml```

# Create test namespaces
```kubectl apply -f team-x/team-x-ns.yaml``` 

```kubectl apply -f team-y/team-y-ns.yaml```

# Deploy test workload to team-x
```kubectl apply -f test-workload.yaml -n team-x``` 

Check that test workload is running on non egress nodes and cannot reach external sites because of the firewall rule:   

```kubectl -n team-x get po -l app=test -o wide```

`kubectl -n team-x exec -it 
    $(kubectl -n team-x get pod -l app=test -o jsonpath={.items..metadata.name}) \
    -c test -- curl -v http://example.com
`

# Restrict the proxy egress routes in team x 

Check the current outbound clusters configured in the proxy in team-x: 

`
${ISTIOCTL} pc c $(kubectl -n team-x get pod -l app=test 
    -o jsonpath={.items..metadata.name}).team-x --direction outbound
`

Restrict the outbound clusters and allow only egress rooutes that have been explicitly defined with service entries in the istio-egress and team-x namespaces:

```kubectl apply -f team-x/sidecar-egress-routes-team-x.yaml```

# Configure the mesh to go through Egress Gateway & configure team x for example.com routes

Create the Gateway: 

```kubectl apply -f egress-gateway.yaml```

Create the DestinationRule 

```kubectl apply -f destination-rule.yaml```

Create a ServiceEntry to register external site example.com

```kubectl apply -f service-entry-examplecom.yaml```

Create a VirtualService to route all traffic to example.com through Egress Gateway

```kubectl apply -f virtual-service-examplecom.yaml```

Check that team x pods can reach example.com

`
for i in {1..4}; do
    kubectl -n team-x exec -it $(kubectl -n team-x get pod -l app=test 
        -o jsonpath={.items..metadata.name}) -c test -- 
    curl -s -o /dev/null -w "%{http_code}\n" http://example.com; done
`

# Configure team y for egress routes

Restrict the proxy egress routes in team y: 

```kubectl apply -f team-y/sidecar-egress-routes-team-y.yaml```

Deploy test workload to team-x:  

```kubectl apply -f test-workload.yaml -n team-y```

Create a service entry for httpbin.org for both teams

```kubectl apply -f service-entry-httpbin.yaml```

Configure the mesh to route traffic to httpbin.org through the egress gateway:

```kubectl apply -f virtual-service-httpbin.yaml```

Test the traffic. team-x and team-y pods can both reach http://httpbin.org:

`
kubectl -n team-x exec -it $(kubectl -n team-x get pod -l app=test 
    -o jsonpath={.items..metadata.name}) -c test -- curl -I http://httpbin.org
`

`
kubectl -n team-y exec -it $(kubectl -n team-y get pod -l app=test 
    -o jsonpath={.items..metadata.name}) -c test -- curl -I http://httpbin.org
`

Team-y cannot reach http://example.com because the route has not been exported to team-y namespace: 

`kubectl -n team-y exec -it $(kubectl -n team-y get pod -l app=test 
    -o jsonpath={.items..metadata.name}) -c test -- curl -I http://example.com
`