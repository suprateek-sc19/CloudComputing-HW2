---
title: "CS-GY 9223 Cloud Computing"
subtitle: "Assignment 2"
author: 
  - "Suprateek Chatterjee sc10344@nyu.edu"
  - "Karmanya Mendiratta km6296@nyu.edu"
format: pdf
number-sections: true
geometry: 
  - vmargin=0.75in
  - hmargin=0.75in
code-line-numbers: true
code-block-border-left: "#ffffff"
highlight-style: atom-one
header-includes:
  - \pagenumbering{gobble}
---


# Kubernetes and Docker

#  Containerizing the application

For this part of the assignment we need to have `docker` and `docker-compose` installed on the machine.

```
$ docker --version
Docker version 24.0.6, build ed223bc
```

```
$ docker compose version
Docker Compose version v2.21.0-desktop.1
```

To containerize the application, we need to create a `Dockerfile` with the following steps to create the image.

```Dockerfile
# Use an official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory in the container
WORKDIR /app

# Copy the current directory contents into the container at /app
COPY . /app

# Install any needed packages specified in requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Make port 3000 available to the world outside this container
EXPOSE 3000

# Define environment variable
ENV FLASK_ENV=development
ENV PORT=3000

# Run app.py when the container launches
CMD ["flask", "run", "--host=0.0.0.0", "--port=3000"]
```

1. __`FROM python`__: This line specifies the base image for the container. In this case, it's using the official Python image as the base for the container.

2. __`WORKDIR /app`__: It sets the working directory within the container to `/app`. This is where subsequent commands will be executed.

3. __`COPY . /app`__: This line copies the contents of the local directory named `web` into the current working directory of the container. The dot `.` represents the current directory in the container.

4. __`RUN pip install -r requirements.txt`__: This command runs the pip install command inside the container. It installs the Python packages listed in the requirements.txt file, assuming that the file exists in the current working directory of the container.

5. __`EXPOSE 3000`__: This line informs Docker that the container will listen on port 5000. However, it doesn't actually publish the port to the host system. We'll need to map this port when running the container.

6. __`CMD flask run --host 0.0.0.0`__: This sets the default command that will be executed when the container is started. It runs the Flask application using `flask run` and binds it to all available network interfaces using `--host 0.0.0.0`. This makes the Flask app accessible externally.

Once the Dockerfile has been created, the next step is to build the image.

```
$ docker build -t cc-flask-app .
```

![docker build output](./screenshots/docker-build-output.png)

## Pushing to Dockerhub

```
$ docker push cc-flask-app
```

![docker push output](./screenshots/docker-push-output.png)

We can see on Docker Hub that the image was pushed successfully.


![docker hub output](./screenshots/docker-hub-output.png)

## Testing the application locally

We will utilize docker-compose to create containers for both the Flask application and a MongoDB instance. The Docker Compose file is written using YAML.

```yaml
version: '3.8'
services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - FLASK_ENV=development
      - MONGO_HOST=mongodb
    depends_on:
      - mongodb

  mongodb:
    image: mongo:latest
    volumes:
      - mongo-data:/data/db

volumes:
  mongo-data:
```

- `version: '3.8'`: Specifies the version of the Docker Compose file format. This determines which features will be available.

- `services`: This is the top-level key in a Docker Compose file, and it defines the list of services or containers we want to create and manage.

### Service: `web`
- This is the name of the first service, which is called "web."
- `build: .`: Indicates that Docker should build the image for this service using the Dockerfile in the current directory.
- `ports`:
  - This section defines port mapping for the container. It maps the host port 3000 to the container port 3000. This allows access to the Flask application on the host machine at port 3000, with Docker forwarding the traffic to the Flask application running inside the container on the same port.
- `environment`:
  - Sets environment variables for the service. `FLASK_ENV` is set to "development", and `MONGO_HOST` is set to "mongodb", directing the Flask application to the MongoDB service for database interactions.
- `depends_on`:
  - Specifies that the "web" service depends on the "mongodb" service, ensuring that the "mongodb" service starts before the "web" service. This is crucial because the Flask application relies on MongoDB for data storage.

### Service: `mongodb`
- This is the name of the second service, which is called "mongodb."
- `image: mongo:latest`: Specifies the Docker image to use for the "mongodb" service, using the latest version of the official MongoDB image.
- `volumes`:
  - Defines a data volume named `mongo-data` for the "mongodb" service. This volume is mounted at `/data/db` inside the container, providing persistent storage for MongoDB data.

### Volumes:
- `mongo-data`: Defines a named volume that persists data stored by the MongoDB container, ensuring data is not lost when the container is stopped or removed.

## Summary
This Docker Compose file configures two services: one for a Flask web application (`web`) and another for a MongoDB database (`mongodb`). It outlines their Docker images, build contexts, port mappings, environment variables, dependencies, and volumes, creating a cohesive and interdependent application environment.


```
$ docker compose up -d
```

![docker compose output](./screenshots/docker-compose-output.png)

Here is the website's user interface when I visit `localhost:3000`

![flask application ui on Docker](./screenshots/flask-application-ui.png)

# Deploying the application on Minikube

For this part of the assignment we need to have `minikube` and `kubectl` installed on the machine.

```
$ minikube version
minikube version: v1.31.2
commit: fd7ecd9c4599bef9f04c0986c4a0187f98a4396e
```

```
$ kubectl version
Client Version: v1.28.3
Kustomize Version: v5.0.4-0.20230601165947-6ce0bf390ce3
Server Version: v1.27.4
```

{{< pagebreak >}}

![minikube start](./screenshots/minikube-start.png)

Next, I'll create the deployment and service for both the Flask app and MongoDB.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app-deployment
spec:
  replicas: 2
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-app
        image: suprateek19/flask-app:latest  
        ports:
        - containerPort: 3000
        env:
        - name: MONGO_HOST
          value: mongodb
        - name: MONGO_PORT
          value: "27017"

---
apiVersion: v1
kind: Service
metadata:
  name: flask-app-service
spec:
  type: NodePort
  ports:
  - port: 3000
    targetPort: 3000
    nodePort: 30007
  selector:
    app: flask-app
```

- Deployment Section:
  - `apiVersion: apps/v1`: Specifies the API version for the Deployment.
  - `kind: Deployment`: Defines the type of Kubernetes resource as a Deployment.
  - `metadata`: Contains metadata for the Deployment, including the name and labels.
  - `spec`: Describes the desired state for the Deployment.
  - `replicas: 2`: Specifies that there should be two replicas of the pod.
  - `selector`: Defines how the Deployment finds which pods to manage.
  - `matchLabels`: Selects pods with the label "app: flask-app".
  - `template`: Describes the pods that will be created.
      - `metadata`: Contains labels for the pod.
      - `spec`: Specifies the pod's specification.
          - `containers`: Defines the containers within the pod.
              - `name`: Names the container "flask-app".
              - `image`: Specifies the Docker image for the Flask app as `suprateek19/flask-app:latest`.
              - `ports`: Specifies that the container will listen on port 3000.
              - `env`: Sets environment variables for the container, such as `MONGO_HOST` with the value `mongodb`.

- Service Section:
  - `apiVersion: v1`: Specifies the API version for the Service.
  - `kind: Service`: Defines the type of Kubernetes resource as a Service.
  - `metadata`: Contains metadata for the Service, including the name.
  - `spec`: Describes the desired state for the Service.
      - `type`: NodePort: Exposes the Service on each node's IP at a static port (nodePort: 30007).
      - `selector`: Selects pods with the label "app: flask-app".
      - `ports`: Specifies the ports that the Service will forward.
          - `port: 3000`: Specifies the port on the Service.
          - `targetPort: 3000`: Specifies the port on the pod to which the Service forwards.


```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongo-deployment
  labels:
    app: mongo
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongo
  template:
    metadata:
      labels:
        app: mongo
    spec:
      containers:
        - name: mongo
          image: mongo
          ports:
            - containerPort: 27017
```
- This section defines a Kubernetes Deployment named "mongo-deployment" for a MongoDB instance.
- One replica of the pod is specified (replicas: 1).
- The pod selector is set to match pods with the label "app: mongo."
- The pod template includes a container named "mongo" using the official MongoDB Docker image.
- The container is configured to listen on port 27017.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: mongo-service
spec:
  type: NodePort
  selector:
    app: mongo
  ports:
    - protocol: TCP
      port: 27017
      targetPort: 27017
      nodePort: 30100
```

- This section defines a Kubernetes Service named "mongo-service" to expose the MongoDB instance.
- The Service type is set to NodePort, exposing the MongoDB service on each node's IP at port 30100.
- The Service selects pods with the label "app: mongo."
- It forwards traffic from port 30100 to port 27017 on the selected pods.

```
$ kubectl apply -f mongo-deployment.yml
deployment.apps/mongo-deployment unchanged
service/mongo-service unchanged
```

```
$ kubectl apply -f web-deployment.yml
deployment.apps/web-deployment unchanged
service/web-service unchanged
```

![kubectl output](./screenshots/kubectl-output.png)

```
$ minikube service --all
```

![minikube service output](./screenshots/minikube-service-output.png)

![flask app ui on Minikube](./screenshots/flask-app-ui-kubernetes.png)

{{< pagebreak >}}

## Adding load balancer

To incorporate the load balancer for the web application, we simply need to update the `spec.type` to `LoadBalancer`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: flask-app-service
spec:
  type: LoadBalancer
  ports:
  - port: 3000
    targetPort: 3000
  selector:
    app: flask-app
```

![flask app load balanced](./screenshots/web-service-load-balanced.png)

# Deploying the application on EKS

Rather than manually setting up the cluster on EKS through the UI, we can streamline the process by utilizing the [eksctl](https://eksctl.io/) CLI, which automates the creation using CloudFormation scripts.

```
$ eksctl version
0.174.0
```
We also have to update the OS of our build on docker to align with our EKS OS. I have run the following command to achieve the same:

![docker buildx](./screenshots/docker-buildx.png)

{{< pagebreak >}}



```
$ eksctl create cluster --name todo-cluster --node-type=t2.large --nodes=4 --region=us-east-2
```

![eksctl create cluster](./screenshots/eksctl-create-cluster.png)

{{< pagebreak >}}

This created a cluster on my AWS EKS as follows:

![EKS with 1 cluster created](./screenshots/EKS-with-one-cluster.png)

Applying the deployments and services for both the flask app and mongoDB:

![Apply deployments](./screenshots/apply_deployment.png)

![Apply services](./screenshots/apply_service.png)

After applying the deployments for both the Flask app and MongoDB.

![Kubect get commands](./screenshots/kubectl_get_commands.png)


{{< pagebreak >}}

![Flask app ui on EKS](./screenshots/flask-app-on-eks.png)

## Adding persistent volume

First, install the EBS CSI driver and controller on the nodes. Second, attach the IAM role.

After this, we will first create a claim for the persistent volume, which will be fulfilled once a pod is attached to it

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongodb-data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

Then we need to attach the MongoDB pod to the persistent volume and mount the location where the data is saved.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mongodb-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mongodb
  template:
    metadata:
      labels:
        app: mongodb
    spec:
      containers:
      - name: mongodb
        image: mongo:latest
        ports:
        - containerPort: 27017
        volumeMounts:
            - name: mongo-storage
              mountPath: /data/db
      volumes:
        - name: mongo-storage
          persistentVolumeClaim:
            claimName: mongo-pvc

---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: mongo-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```

For this to work we also had to give some IAM permissions to the Node IAM Role arn. The following policies were added to our role:

![Create volume policy](./screenshots/create-volume-policy-code.png)

Thus, the following are the policies attached to our node:

![Created volume policy](./screenshots/created-volume-policy.png)

We can see that the PVC is bound to our mongo-pvc.

![PVC bound to MongoDB pod](./screenshots/pvc-bound.png)

# Replacing Deployments with Replication Controller

To test out replication controller, we will delete the deployment that we previously applied. Here is the replication controller code that will be applied.

flask-app-rc.yaml

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: flaskapp-rc
spec:
  replicas: 6
  selector:
    app: flaskapp
  template:
    metadata:
      labels:
        app: flaskapp
    spec:
      containers:
      - name: flaskapp
        image: karmanya1804/todoapp:v2 
        ports:
        - containerPort: 3000
```

Now, we will apply the replication controller:



![Kubectl apply replication controller](./screenshots/kubectl-apply-replication-controller.png)

![Kubectl get replication controller pods](./screenshots/replication-controller-pods.png)

In the above screenshot, we can see that the desired number of requested pods is 3, and currently, 3 pods are running.

On running kubectl get replicationcontroller, we can see that the replication controller is created with the 3 desired pods

![Kubectl get replication controller](./screenshots/get-replication-controller-3.png)

## Deleting one of the pods

Now let’s delete one of the replicas and see whether the replication controller is keeping the
desired number of replicas or not.

![Terminated pod is successfully replaced](./screenshots/pod-replaced.png)

On deleting the pod flaskapp-rc-rvxh7, the replication controller instantly created a new pod and replaced the delete one

{{< pagebreak >}}

## Updating the number of replicas

Specifying 6 replicas for the Flask app.

![Scaling up the replicas](./screenshots/replicas-scale-up.png)

![Scaled up replica pods](./screenshots/scaled-up-replica-pods.png)

We can see that the number of replication went up to 6 hence our replication controller is
working as expected.

# Performing rolling update

First, we need to push a new version of the image. Here I'm creating a new tag called 'v2' and pushing it to dockerhub.

![docker push v2](./screenshots/docker-push-v2.png)

{{< pagebreak >}}

![dockerhub v2 tag](./screenshots/docker-hub-v2.png)

Then we will update the strategy in the flask-app-deployment.yaml file.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app-deployment
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-app
        image: karmanya1804/todoapp:v2
        ports:
        - containerPort: 3000
        env:
        - name: MONGO_HOST
          value: mongodb
        - name: MONGO_PORT
          value: "27017"
```

![Image version before updating containers](./screenshots/image-version-before-rolling-update.png)

We can see that the image here is karmanya1804/todoapp:latest

Now we will apply our new rolling update strategy

![Applying the new rolling update strategy](./screenshots/applying-the-rolling-update.png)

{{< pagebreak >}}

The image of the new pods are changed to karmanya1804/todoapp:v2

![Image version after updating containers](./screenshots/image-version-after-rolling-update.png)


# Liveness and Readiness probes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: flask-app-deployment
spec:
  replicas: 2
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  selector:
    matchLabels:
      app: flask-app
  template:
    metadata:
      labels:
        app: flask-app
    spec:
      containers:
      - name: flask-app
        image: karmanya1804/todoapp:v2
        ports:
        - containerPort: 3000
        env:
        - name: MONGO_HOST
          value: mongodb
        - name: MONGO_PORT
          value: "27017"
        livenessProbe:                            
            tcpSocket:                              
              port: 3000                            
            initialDelaySeconds: 5                  
            periodSeconds: 5                        
        readinessProbe:                           
            httpGet:                                
              path: /                                   
              port: 3000                            
              httpHeaders:                          
            initialDelaySeconds: 10                 
            periodSeconds: 10
```

To test the readiness probe, I'll delete the mongo service and pod. The Flask app won't be able to reach the MongoDB instance, causing a 500 error code when the readiness probe attempts to reach it. This will result in no traffic being routed to that pod. Since all the other pods that are part of the replica set won't be able to connect to the MongoDB instance, no pod will receive any incoming traffic. Consequently, the client will receive an error indicating that the site is unreachable.

![readiness probe fails](./screenshots/readiness-probe-fail.png)

{{< pagebreak >}}

![all pods down](./screenshots/all-pods-down.png)

{{< pagebreak >}}

We can see that the flask app is now in not ready state and the readiness probe must also show
that there is an error.

![readiness probe failed](./screenshots/readiness-probe-error.png)

The application website is also down

![website down](./screenshots/flask-app-down.png)

On turning the mongoDB service back on, we can see that all the pods are back up

{{< pagebreak >}}

![all pods up](./screenshots/all-pods-up.png)

In a similar fashion we can test for the liveness probe as well. One way could be to not start the application and the liveness probe will fail to setup tcp connection on port 5000.

# Alerting with Prometheus

The procedure involves transferring metrics data from the Metrics Server to the AMP (Application Monitoring Platform) using a Prometheus server installed within Kubernetes cluster through Helm. [Here](https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-ingest-metrics-new-Prometheus.html) is the guide on how to do this.

![prometheus server up and running](./screenshots/prometheus-server-running.png)

Now that our prometheus server is setup, we need to add alerts and setup the alert manager configs so that whenever the alert is triggered, the prometheus server hits our slack api and sends an alert message on the slack channel. To do this, first we will create a alertmanager-config.yaml, which consists of the web-hook url of slack-api, through which we will connect out Prometheus server to the slack channel.

Below is the alertmanager-config.yaml file:

![SNS email subscriber](./screenshots/sns-setup-subscriber.png)

**Note**: Make sure the following access policy is attached to the topic

```yaml
{
    apiVersion: v1
data:
  alertmanager.yml: |
    global:
      resolve_timeout: 1m
      slack_api_url: 'https://hooks.slack.com/services/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'
    route:
      receiver: 'slack-notifications'
      group_interval: 5m
      group_wait: 10s
      repeat_interval: 3h
    receivers:
      - name: 'slack-notifications'
        slack_configs:
          - channel: '#prometheus-alerts'
            send_resolved: true
            icon_url: https://avatars3.githubusercontent.com/u/3380462
            title: |-
              [{{ .Status | toUpper }}{{ if eq .Status "firing" }}:{{ .Alerts.Firing | len }}{{ end }}] Monitoring - {{ .CommonLabels.alertname }}
              {{- if gt (len .CommonLabels) (len .GroupLabels) -}}
                {{" "}}(
                {{- with .CommonLabels.Remove .GroupLabels.Names }}
                  {{- range $index, $label := .SortedPairs -}}
                    {{ if $index }}, {{ end }}
                    {{- $label.Name }}="{{ $label.Value -}}"
                  {{- end }}
                {{- end -}}
                )
              {{- end }}
            text: >-
              {{ range .Alerts -}}
              Alert: {{ .Annotations.title }}{{ if .Labels.severity }} - {{ .Labels.severity }}{{ end }}
              Description: {{ .Annotations.description }}
              Details:
                {{ range .Labels.SortedPairs }} • {{ .Name }}: {{ .Value }}
                {{ end }}
              {{ end }}
    templates:
      - /etc/alertmanager/*.tmpl
kind: ConfigMap
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","data":{"alertmanager.yml":"global:\n  resolve_timeout: 1m\n  slack_api_url: 'https://hooks.slack.com/services/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'\nroute:\n  receiver: 'slack-notifications'\n  group_interval: 5m\n  group_wait: 10s\n  repeat_interval: 3h\nreceivers:\n  - name: 'slack-notifications'\n    slack_configs:\n      - channel: '#prometheus-alerts'\n        send_resolved: true\n        icon_url: https://avatars3.githubusercontent.com/u/3380462\n        title: |-\n          [{{ .Status | toUpper }}{{ if eq .Status \"firing\" }}:{{ .Alerts.Firing | len }}{{ end }}] Monitoring - {{ .CommonLabels.alertname }}\n          {{- if gt (len .CommonLabels) (len .GroupLabels) -}}\n            {{\" \"}}(\n            {{- with .CommonLabels.Remove .GroupLabels.Names }}\n              {{- range $index, $label := .SortedPairs -}}\n                {{ if $index }}, {{ end }}\n                {{- $label.Name }}=\"{{ $label.Value -}}\"\n              {{- end }}\n            {{- end -}}\n            )\n          {{- end }}\n        text: \u003e-\n          {{ range .Alerts -}}\n          Alert: {{ .Annotations.title }}{{ if .Labels.severity }} - {{ .Labels.severity }}{{ end }}\n          Description: {{ .Annotations.description }}\n          Details:\n            {{ range .Labels.SortedPairs }} • {{ .Name }}: {{ .Value }}\n            {{ end }}\n          {{ end }}\ntemplates:\n  - /etc/alertmanager/*.tmpl\n"},"kind":"ConfigMap","metadata":{"annotations":{"meta.helm.sh/release-name":"prometheus","meta.helm.sh/release-namespace":"default"},"creationTimestamp":"2024-03-18T09:58:57Z","labels":{"app.kubernetes.io/instance":"prometheus","app.kubernetes.io/managed-by":"Helm","app.kubernetes.io/name":"alertmanager","app.kubernetes.io/version":"v0.27.0","helm.sh/chart":"alertmanager-1.9.0"},"name":"prometheus-alertmanager","namespace":"default","resourceVersion":"350874","uid":"8fd7a888-54be-4266-a0ed-8cf9ee91428a"}}
    meta.helm.sh/release-name: prometheus
    meta.helm.sh/release-namespace: default
  creationTimestamp: "2024-03-18T09:58:57Z"
  labels:
    app.kubernetes.io/instance: prometheus
    app.kubernetes.io/managed-by: Helm
    app.kubernetes.io/name: alertmanager
    app.kubernetes.io/version: v0.27.0
    helm.sh/chart: alertmanager-1.9.0
  name: prometheus-alertmanager
  namespace: default
  resourceVersion: "351293"
  uid: 8fd7a888-54be-4266-a0ed-8cf9ee91428a

}
```

In this file, we have fetched the alert manager configs already present on the prometheus service and added our own configs to it. We have added the configs in 'alertmanager.yml:' value in the data field. The config specifies the slack-api url, the channel name, the receiver name and other essential configs required to send a notification to slack.

Once prometheus server is setup, next we need to create the alert definition to send the alerts to SNS topic.

```yaml
alertmanager_config:
  route:
    receiver: 'sns-receiver'
  receivers:
    - name: 'sns-receiver'
      sns_configs:
      - topic_arn: 'arn:aws:sns:us-east-2:197499403368:amp-alerts'
        sigv4:
          region: us-east-2
        subject: 'amp alert'
```

Next, We will look into prometheus-config.yaml file, specifically the rules section which defines our alerting rules, which if broken, will lead to the alert getting triggered and the alertmanager will then send a slack notification.

```yaml
rules: |
    groups:
      - name: alerting-rules
        rules:
        - alert: HighFailureRate
          annotations:
            description: '{{ $labels.pod }} has restarted {{ $value }} times in the last
              10 minutes.'
            summary: High failure rate detected in pod {{ $labels.pod }}
          expr: increase(kube_pod_container_status_restarts_total[10m]) > 1
          for: 1m
          labels:
            severity: critical
```
This configuration sets up a critical alert in Prometheus, designed to trigger when a pod within the observed scope experiences an increase in restarts exceeding a certain threshold over a 10-minute window. Specifically, the alert is named "HighFailureRate" and will fire if there is an increase of more than one restart during the last 10 minutes. For the alert to be activated, the specified condition must be met continuously for at least 1 minute.

Now, to test that out alert is working as expected, we will create a new yaml file called faulty-pod.yaml. This file defines the configurations to create a pod that will consistently fail and restart, thus allowing us to check if the alert we have created to check the number of restarts of a pod is working.

``` faulty-pod.yaml ```

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: faulty-pod
spec:
  replicas: 1
  selector:
    matchLabels:
      app: faulty-pod
  template:
    metadata:
      labels:
        app: faulty-pod
    spec:
      containers:
      - name: faulty-container
        image: busybox
        command: ["sh", "-c", "exit 1"]
```
Upon applying this configuration, we can see that the pod is created and is continuously failing and retrying.

![faulty pod](./screenshots/faulty-pod.png)

We can see that our pod is in CrashLoopBackoff status and we can observe on our prometheus dashboard now that the alert we created earlier has started firing

![Alert firing](./screenshots/prometheus-alert-firing.png)

In the alertmanager dashboard, we can see that our prometheus alert has called the alertmanager successfully and now we should be getting alerts on slack.

![AlertManager dashboard](./screenshots/alertmanager-dashboard.png)

Here is the slack message received when the faulty pod is down and the alertmanager has sent the notification:

{{< pagebreak >}}

![slack message](./screenshots/alert-slack.png)

This is the complete alert that was received in the notification:

``` yaml
[FIRING:2] Monitoring - HighFailureRate (alertname="HighFailureRate", app_kubernetes_io_component="metrics", app_kubernetes_io_instance="prometheus", app_kubernetes_io_managed_by="Helm", app_kubernetes_io_name="kube-state-metrics", app_kubernetes_io_part_of="kube-state-metrics", app_kubernetes_io_version="2.10.1", container="faulty-container", helm_sh_chart="kube-state-metrics-5.16.4", instance="192.168.16.245:8080", job="kubernetes-service-endpoints", namespace="default", node="ip-192-168-1-210.us-east-2.compute.internal", service="prometheus-kube-state-metrics", severity="critical")
Alert:  - critical Description: faulty-pod-7bd7b48bb8-rn8r2 has restarted 1.3076666666666665 times in the last 10 minutes. Details:
  • alertname: HighFailureRate
  • app_kubernetes_io_component: metrics
  • app_kubernetes_io_instance: prometheus
  • app_kubernetes_io_managed_by: Helm
  • app_kubernetes_io_name: kube-state-metrics
  • app_kubernetes_io_part_of: kube-state-metrics
  • app_kubernetes_io_version: 2.10.1
  • container: faulty-container
  • helm_sh_chart: kube-state-metrics-5.16.4
  • instance: 192.168.16.245:8080
  • job: kubernetes-service-endpoints
  • namespace: default
  • node: ip-192-168-1-210.us-east-2.compute.internal
  • pod: faulty-pod-7bd7b48bb8-rn8r2
  • service: prometheus-kube-state-metrics
  • severity: critical
  • uid: 7b48dc81-6b97-4b7c-8cb6-206426b088ab
  ```
