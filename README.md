---
title: "CS-GY 9223 Cloud Computing"
subtitle: "Assignment 2"
author: 
  - "Suprateek Chatterjee sc10344@nyu.edu"
  - "Karmanya Mendiratta @nyu.edu"
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
Docker Compose version v2.23.0-desktop.1
```

To containerize the application, we need to create a `Dockerfile` with the following steps to create the image.

```Dockerfile
FROM python
WORKDIR /app
COPY web .
RUN pip install -r requirements.txt
EXPOSE 5000
CMD flask run --host 0.0.0.0
```

1. __`FROM python`__: This line specifies the base image for the container. In this case, it's using the official Python image as the base for the container.

2. __`WORKDIR /app`__: It sets the working directory within the container to `/app`. This is where subsequent commands will be executed.

3. __`COPY web .`__: This line copies the contents of the local directory named `web` into the current working directory of the container. The dot `.` represents the current directory in the container.

4. __`RUN pip install -r requirements.txt`__: This command runs the pip install command inside the container. It installs the Python packages listed in the requirements.txt file, assuming that the file exists in the current working directory of the container.

5. __`EXPOSE 5000`__: This line informs Docker that the container will listen on port 5000. However, it doesn't actually publish the port to the host system. We'll need to map this port when running the container.

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
services:
  web:
    image: cc-flask-app
    ports:
      - "8000:5000"
    depends_on:
      - mongodb
    environment:
      - MONGO_HOST=mongodb
  mongodb:
    image: mongo
    ports:
      - 27017:27017
    volumes:
      - .data:/data/db
```

- `services`: This is the top-level key in a Docker Compose file, and it defines the list of services or containers we want to create and manage.

- `web`: This is the name of the first service, which is called "web."

- `image: cc-flask-app`: It specifies the Docker image to use for the "web" service. In this case, it will use the image named "cc-flask-app," which likely contains our Flask web application.

- `ports`: This section defines port mapping for the container. Here, it maps the host port 8000 to the container port 5000. So, we can access the Flask application on our host machine at port 8000, and Docker will forward the traffic to the Flask application running inside the container on port 5000.

- `depends_on`: This specifies that the "web" service depends on the "mongodb" service. It ensures that the "mongodb" service is started before the "web" service. This is important since our Flask application relies on the MongoDB service.

- `environment`: In this section, we can set environment variables for the "web" service. Here, it's setting the MONGO_HOST environment variable to "mongodb." This tells the Flask application where to find the MongoDB service.

- `mongodb`: This is the name of the second service, which is called "mongodb."

- `image: mongo`: This specifies the Docker image to use for the "mongodb" service. It's using the official MongoDB image.

- `ports`: Similar to the "web" service, this section maps the host port 27017 to the container port 27017. It allows us to access the MongoDB service on the host at port 27017.

- `volumes`: This is used to define a data volume for the "mongodb" service. It binds the .data directory on the host to the /data/db directory inside the container. This is typically used to persist data outside the container, ensuring that data is not lost when the container is stopped or removed.

In summary, this Docker Compose file configures two services: one for our Flask web application and another for a MongoDB database. It specifies their respective Docker images, port mappings, dependencies, environment variables, and data volume to create a complete and interrelated application environment.

```
$ docker compose up -d
```

![docker compose output](./screenshots/docker-compose-output.png)

Here is the website's user interface when I visit `localhost:8000`

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
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 1
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: cc-flask-app
          ports:
            - containerPort: 5000
          env:
            - name: MONGO_HOST
              value: mongo-service
---
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: NodePort
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
      nodePort: 31000
```

- Deployment Section:
    - `apiVersion: apps/v1`: Specifies the API version for the Deployment.
    - `kind: Deployment`: Defines the type of Kubernetes resource as a Deployment.
    - `metadata`: Contains metadata for the Deployment, including the name and labels.
    - `spec`: Describes the desired state for the Deployment.
    - `replicas: 1`: Specifies that there should be one replica of the pod.
    - `selector`: Defines how the Deployment finds which pods to manage.
    - `matchLabels`: Selects pods with the label "app: web."
    - `template`: Describes the pods that will be created.
    - `metadata`: Contains labels for the pod.
    - `spec`: Specifies the pod's specification.
    - `containers`: Defines the containers within the pod.
    - `name`: web: Names the container "web."
    - `image`: cc-flask-app: Specifies the Docker image for the Flask app.
    - `ports`: Specifies that the container will listen on port 5000.
    - `env`: Sets environment variables for the container, like `MONGO_HOST` with the value `mongo-service`.

- Service Section:
    - `apiVersion: v1`: Specifies the API version for the Service.
    - `kind: Service`: Defines the type of Kubernetes resource as a Service.
    - `metadata`: Contains metadata for the Service, including the name.
    - `spec`: Describes the desired state for the Service.
    - `type`: NodePort: Exposes the Service on each node's IP at a static port (in this case, 31000).
    - `selector`: Selects pods with the label "app: web."
    - `ports`: Specifies the ports that the Service will forward.
    - `protocol`: TCP: Specifies the protocol.
    - `port: 5000`: Specifies the port on the Service.
    - `targetPort: 5000`: Specifies the port on the pod.

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

The network is limited if using the Docker driver on Darwin, Windows, or WSL, and the Node IP is not reachable directly. The solution to get around this issue is documented [here](https://minikube.sigs.k8s.io/docs/handbook/accessing/)

![minikube service output](./screenshots/minikube-service-output.png)

![flask app ui on Minikube](./screenshots/flask-app-ui-kubernetes.png)

{{< pagebreak >}}

## Adding load balancer

To incorporate the load balancer for the web application, we simply need to update the `spec.type` to `LoadBalancer`.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: web-service
spec:
  type: LoadBalancer
  selector:
    app: web
  ports:
    - protocol: TCP
      port: 5000
      targetPort: 5000
      nodePort: 31000
```

![flask app load balanced](./screenshots/web-service-load-balanced.png)

# Deploying the application on EKS

Rather than manually setting up the cluster on EKS through the UI, we can streamline the process by utilizing the [eksctl](https://eksctl.io/) CLI, which automates the creation using CloudFormation scripts.

```
$ eksctl version
0.164.0-dev+3cdb1af9e.2023-10-27T12:24:20Z
```

{{< pagebreak >}}

![EKS no cluster](./screenshots/EKS-no-cluster.png)

```
$ eksctl create cluster --node-type=t2.large --nodes=4 --region=us-east-2
```

![eksctl create cluster](./screenshots/eksctl-create-cluster.png)

{{< pagebreak >}}

![EKS with 1 cluster created](./screenshots/EKS-with-one-cluster.png)

After applying the deployments for both the Flask app and MongoDB.

![Deployment on AWS EKS cluster](./screenshots/eks-deployment.png)

{{< pagebreak >}}

![Flask app ui on EKS](./screenshots/flask-app-on-eks.png)

## Adding persistent volume

First, install the EBS CSI driver and controller on the nodes. Second, attach the IAM role.

```
$ eksctl create addon --name aws-ebs-csi-driver --cluster=CLUSTER_NAME
$ eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=CLUSTER_NAME --approve
```

![EBS CSI drivers and contollers](./screenshots/ebs-csi-drivers.png)

A modification needs to be made to the role attached to the nodegroup for pvc to work fine.

![EBS CSI role attached to the nodegroup](./screenshots/ebs-csi-role.png)

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
          volumeMounts:                     #  
            - name: persistent-storage      # 
              mountPath: /data/db           # attached a persistent
      volumes:                              # volume to the pod
        - name: persistent-storage          # running mongodb
          persistentVolumeClaim:            # 
            claimName: mongodb-data         # 
```

![PVC bound to MongoDB pod](./screenshots/pvc-bound.png)

# Replacing Deployments with Replication Controller

To test out replication controller, we will delete the deployment that we previously applied. Here is the replication controller code that will be applied.

```yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: web
spec:
  replicas: 3
  selector:
    app: web
  template:
    metadata:
      name: web
      labels:
        app: web        # using the same label so that web service will attach to it
    spec:
      containers:
        - name: web
          image: cc-flask-app
          ports:
            - containerPort: 5000
          env:
            - name: MONGO_HOST
              value: mongo-service
```

![Kubectl deleting web deployment](./screenshots/kubectl-delete-deployment.png)

![Kubectl apply replication controller](./screenshots/kubectl-apply-replication-controller.png)

In the above screenshot, we can see that the desired number of requested pods is 3, and currently, 3 pods are running.

![Flask app ui after replication controller](./screenshots/flask-app-ui-replication-controller.png)

{{< pagebreak >}}

## Deleting one of the pods

![Terminated pod is successfully replaced](./screenshots/pod-replaced.png)

{{< pagebreak >}}

## Updating the number of replicas

Specifying 6 replicas for the Flask app.

![Scaling up the replicas](./screenshots/replicas-scale-up.png)

Specifying 3 replicas for the Flask app.

![Scaling down the replicas](./screenshots/replicas-scale-down.png)

# Performing rolling update

First, we need to push a new version of the image. Here I'm doing a multi-arch build for the new image.

```
$ docker buildx build --platform linux/amd64,linux/arm64 -t cc-flask-app:2.0 --push .
```

{{< pagebreak >}}

![Flask app new version pushed](./screenshots/web-app-new-version.png)

Then we will update the strategy in the web deployment spec.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  strategy:                                     # 
    type: RollingUpdate                         #
    rollingUpdate:                              #  Specifying the rolling update
      maxSurge: 1                               #
      maxUnavailable: 1                         #
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: cc-flask-app:2.0        # changed the version of the image
          ports:
            - containerPort: 5000
          env:
            - name: MONGO_HOST
              value: mongo-service
```

![Image version before updating containers](./screenshots/image-version-before-rolling-update.png)

![Applying the new rolling update strategy](./screenshots/applying-the-rolling-update.png)

{{< pagebreak >}}

![Image version after updating containers](./screenshots/image-version-after-rolling-update.png)

![Flask app ui v2 on EKS](./screenshots/flask-app-ui-v2.png)

# Liveness and Readiness probes

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-deployment
  labels:
    app: web
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  template:
    metadata:
      labels:
        app: web
    spec:
      containers:
        - name: web
          image: cc-flask-app:2.0
          ports:
            - containerPort: 5000
          env:
            - name: MONGO_HOST
              value: mongo-service
          livenessProbe:                            # Add liveness probe
            tcpSocket:                              #
              port: 5000                            #
            initialDelaySeconds: 5                  #
            periodSeconds: 5                        #
          readinessProbe:                           # Add readiness probe
            httpGet:                                #
              path: /                               #     
              port: 5000                            #
              httpHeaders:                          #
            initialDelaySeconds: 10                 #
            periodSeconds: 10                       #
```

To test the readiness probe, I'll delete the mongo service and pod. The Flask app won't be able to reach the MongoDB instance, causing a 500 error code when the readiness probe attempts to reach it. This will result in no traffic being routed to that pod. Since all the other pods that are part of the replica set won't be able to connect to the MongoDB instance, no pod will receive any incoming traffic. Consequently, the client will receive an error indicating that the site is unreachable.

![readiness probe fails](./screenshots/readiness-probe-fail.png)

{{< pagebreak >}}

![all pods down](./screenshots/all-pods-down.png)

![all pods down detailed view](./screenshots/all-pods-down-detailed-view.png)

{{< pagebreak >}}

![website down](./screenshots/flask-app-down.png)

![readiness probe works](./screenshots/readiness-probe-works.png)

{{< pagebreak >}}

![all pods up](./screenshots/all-pods-up-detailed-view.png)

In a similar fashion we can test for the liveness probe as well. One way could be to not start the application and the liveness probe will fail to setup tcp connection on port 5000.

# Alerting with AWS Managed Prometheus

Data from the metrics server will be pushed to the AMP through the prometheus server that will be installed in cluster through helm. [Here](https://docs.aws.amazon.com/prometheus/latest/userguide/AMP-onboard-ingest-metrics-new-Prometheus.html) is the guide on how to do this.

![prometheus server up and running](./screenshots/prometheus-server-running.png)

We need to setup the SNS topic that will be used to send out the alert on email.

![SNS email subscriber](./screenshots/sns-setup-subscriber.png)

**Note**: Make sure the following access policy is attached to the topic

```json
{
    "Sid": "Allow_Publish_Alarms",
    "Effect": "Allow",
    "Principal": {
        "Service": "aps.amazonaws.com"
    },
    "Action": [
        "sns:Publish",
        "sns:GetTopicAttributes"
    ],
    "Resource": "arn:aws:sns:us-east-2:197499403368:amp-alerts",
    "Condition": {
        "StringEquals": {
            "AWS:SourceAccount": "197499403368"
        },
        "ArnEquals": {
            "aws:SourceArn": "arn:aws:aps:us-east-2:197499403368:workspace/<id>"
        }
    }
}
```

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

![AMP alert definition](./screenshots/amp-alert-definition.png)

Next, we can add the rule, which will fire when no instance of the flask app is running.

```yaml
groups:
- name: example_alerts_new
  rules:
    - alert: InsufficientReplicas
      expr: | 
            scalar(
                    kube_deployment_status_replicas_available{
                        deployment="web-deployment"
                    }
            ) == bool 0
      for: 0m
      labels:
        severity: critical
      annotations:
        summary: "Insufficient Replicas for web-deployment"
        description: "Available replicas for web-deployment is zero"
```

![AMP rule added](./screenshots/amp-rule-added.png)

To trigger the alert the same condition is created as mentioned under testing readiness probe.

![Flask app instance down](./screenshots/instances-down.png)

Here is the email alert received when all the web instances were down. 

{{< pagebreak >}}

![Sample email](./screenshots/alert-email.png)
