## TMC Polices

Demonstrates various tmc policies

| Policy Types   | Applies To            |
|----------------|-----------------------|
| Access         | Workspace / Namespace |
| Image registry | Workspace / Namespace |
| Network.       | Workspace / Namespace |
| Security.      | Cluster / Group.      |
| Quota.         | Cluster / Group.      |
| Custom.        | Cluster / Group.      |

### General Setup

- In TMC Create/Attach one or more clusters to a cluster group.
- Create a workspace (collection of namespaces) eg. "Apps"
- In one or more clusters, select Namespaces and "Create Namespace"
- Create two or more namespaces eg. "App1", "App2" etc.
- When creating the namespace add a label eg. "type=app"

### Demonstrate Policies

Access Policy (applies to workspace/namespace)
---

**Setup**
Create a user or group in your integrated kubernetes identity management system. For example for vSphere Tanzu, in vCenter select Administration, Users & Groups and create a user or group. 

**Apply Policy**
- Select Policies -> Assignments
- Select Access and then Workspaces
- Select your workspace eg. "Apps"
- Select Create Role Binding

- Select the role from dropdown (these are defined in the TMC Administration -> Roles section)
- Select User or Group
- Enter the user or group id from the setup step above

**Policy In Action**

- You should now be able to see that a rolebinding was created in each of the namespaces in your workspace eg. "App1", "App2"

```
kubectl get rolebinding -n app1
NAME.                                                                    ROLE               AGE
rid-ws-a0f6...-bmullan-apps-rbac.authorization.k8s.io-ClusterRole-edit   ClusterRole/edit   111m
```

- In this case the user group 'dev-users' was mapped to the cluster role 'edit'
```
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: Group
  name: dev-users
```


Image Registry (applies to workspace/namespace)
---

**Setup**
You will need access to an image registry, and possibly need to create an image pull secret which can be added to your default service account or configured in the pod image spec. See [here](https://kubernetes.io/docs/tasks/configure-pod-container/configure-service-account/#add-imagepullsecrets-to-a-service-account) for more information

**Apply Policy**
- Select Policies -> Assignments
- Select **Image Registry** and then Workspaces
- Select your workspace eg. "Apps"
- Select **Create Image Registry Policy**

- From the Image Registry template dropdown select **Custom**
- Add a policy name eg. **harbor-registry-policy**
- Under **Hostname** enter the hostname of your registry eg. **harbor.tanzu.be**
- IMPORTANT - Click "Add Another Rule" to add it.
- Click **Create Policy**


**Policy In Action**
- Attempt to run a pod with an image from (default) dockerhub

```
kubectl run --restart=Never -n app1 nginx --image=nginx

Error from server ([denied by tmc.wsp.app1.harbor-registry-policy] container <nginx> has an invalid image reference <nginx>. allowed image patterns are: {hostname: [harbor.tanzu.be], image name: []}): admission webhook "validation.gatekeeper.sh" denied the request: [denied by tmc.wsp.app1.harbor-registry-policy] container <nginx> has an invalid image reference <nginx>. allowed image patterns are: {hostname: [harbor.tanzu.be], image name: []}
```



Network Policy (applies to workspace/namespace)
---

**Setup**
In this example we will create network polices so that all ingress is denied to pods in our namespaces and then allow ingress only from one of our namespaces ie. pods in app1 can talk to pods in app2, and app2 to app1.

**Apply Policy**
- Select Policies -> Assignments
- Select **Network** and then Workspaces
- Select your workspace eg. "Apps"
- Select **Create Network Policy**
- Select **deny-all** from Network Policy.
- Enter policy name eg deny-all-ingress
- Select Create Policy
- Select **Create Network Policy** to create another network policy
- Select ***Custom-Ingress*** from Network Policy
- Under **Rule** select **Selector**
- Under Namespace Selectors enter a label (the same as used in preparation to label the namespaces) 
- eg. "type" "app"
- IMPORTANT : Select "Add Namespace Selector" to save it
- Select **Save** to save the policy

**Policy In Action**
- deploy a set of test pods and services defined in pods.yaml.
```
kubectl create -f yaml/pods.yaml
```
- This will deploy pods node-app and net-tools into namespaces default, app1 and app2 (you may have to change the namespaces to match what you created in preparation).
- Test connection from default namespace (success)
```
kubectl exec -it net-tools -- /bin/bash

bash-5.1# nslookup node-app.default
Server:		198.51.100.10
Address:	198.51.100.10#53
Name:	node-app.default.svc.cluster.local
Address: 198.51.100.90

bash-5.1# curl node-app.default:8080
Hello World!
```
- Attempt to connect to node-app in app1 (failure)
```
bash-5.1# nslookup node-app1.app1
Server:		198.51.100.10
Address:	198.51.100.10#53

Name:	node-app1.app1.svc.cluster.local
Address: 198.51.100.93

bash-5.1# curl node-app1.app1:8080
curl: (28) Failed to connect to node-app1.app1 port 8080: Operation timed out
```
- Attempt to connect from namespace app1 to app2 (success)
```
$ kubectl exec -it net-tools -n app1 -- /bin/bash
bash-5.1# nslookup node-app2.app2
Server:		198.51.100.10
Address:	198.51.100.10#53

Name:	node-app2.app2.svc.cluster.local
Address: 198.51.100.94

bash-5.1# curl node-app2.app2:8080
Hello World!
```


Quota (applies to cluster/group)
---

**Setup**
A quota policy applied to a cluster (and optionally a subset of namespaces) will require that pods specify resource requests and limits, and that those requests and limits are below a specified threshold. 
**Apply Policy**
- Select Policies -> Assignments
- Select **Quota** and then **Clusters**
- Select your cluster or cluster group from the list
- Select **Create Quota Policy**

- From the list of Quota Policies select **Small**
- Specify a policy name eg. small-quota-policy
- Under "Include only specific namespaces"
- Enter a label and value to select just our app1 and app2 namespaces ie. "type" = "app" (specified when we created the namespaces)
- This will limit the impact to just those namespaces


**Policy In Action**
- Verify that the quotas were created in just our namespaces
```
kubectl get quota -A
NAMESPACE   NAME                        AGE   REQUEST                                          LIMIT
app1        tmc.cp.small-quota-policy   13s   requests.cpu: 0/500m, requests.memory: 0/512Mi   limits.cpu: 0/1, limits.memory: 0/2Gi
app2        tmc.cp.small-quota-policy   13s   requests.cpu: 0/500m, requests.memory: 0/512Mi   limits.cpu: 0/1, limits.memory: 0/2Gi
```
- Verify the that request and limit values are required to deploy a pod (failure)
```
kubectl create -f yaml/quota-pod.yaml
Error from server (Forbidden): error when creating "yaml/quota-pod.yaml": pods "quota-pod" is forbidden: failed quota: tmc.cp.small-quota-policy: must specify limits.cpu,limits.memory,requests.cpu,requests.memory
```
- Uncomment the request and limit values, and verify quota is applied if the request is too big (failure)
```
kubectl create -f yaml/quota-pod.yaml
Error from server (Forbidden): error when creating "yaml/quota-pod.yaml": pods "quota-pod" is forbidden: exceeded quota: tmc.cp.small-quota-policy, requested: requests.memory=1Gi, used: requests.memory=0, limited: requests.memory=512Mi
```
- Finally, change the memory request to 512Mi and try the create again (success)
```
          requests:
            memory: "512Mi"
            cpu: "250m"

k create -f yaml/quota-pod.yaml
pod/quota-pod created
```








