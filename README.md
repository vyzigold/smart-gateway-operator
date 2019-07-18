# smart-gateway-operator

Operator for the infra.watch [smart gateway](https://github.com/redhat-service-assurance/smart-gateway)

## Deployment

Deploy the components under the `deploy/` directory.

```shell
oc login -u system:admin
oc apply -f deploy/operator.yaml
oc apply -f deploy/crds/smartgateway_v1alpha1_smartgateway_crd.yaml
oc apply -f deploy/role_binding.yaml
oc apply -f deploy/role.yaml
oc apply -f deploy/service_account.yaml
```

## Build and test

A procedure for testing in minishift

### Set up minishift and docker

Enable the edge routing for the minishift registry and log into it:

```shell
minishift addons enable registry-route # Must be BEFORE you start minishift (https://github.com/minishift/minishift/issues/2060)
minishift addons enable admin-user
minishift start
oc login -u admin -p admin
oc new-project sg-test
docker login -u admin -p `oc whoami -t` $(minishift openshift registry)
```

### Build the operator

Build a "dev" version of the operator image:

```shell
DOCKER_IMAGE="$(minishift openshift registry)/$(oc project -q)/smart-gateway-operator:dev"
operator-sdk build "${DOCKER_IMAGE}"
docker push "${DOCKER_IMAGE}"
```

### Deploy with the newly built operator

Follow the same process as documented in the "Deployment" section above, but
apply a patched version of the operator resource that uses the newly built
operator image:

```shell
oc patch --dry-run -f deploy/operator.yaml -o yaml -p \
  '{"spec":{"template":{"spec":{"containers":[{"name": "smart-gateway-operator", "image": "'"$(oc registry info)/$(oc project -q)"'/smart-gateway-operator:dev"}]}}}}' \
  | oc apply -f -
... (See above)
```

### FIXME - Unit testing

With molecule (Currently broken)

### Integration testing

Test the newly built operator with the Service Assurance Framework (SAF).

#### Prepare project

Create the sa-telemetry project and push the operator image to an image stream
in its registry namespace.

```shell
oc delete project sa-telemetry
oc new-project sa-telemetry
SA_DOCKER_IMAGE="$(minishift openshift registry)/$(oc project -q)/smart-gateway-operator:latest"
docker tag "${DOCKER_IMAGE}" "${SA_DOCKER_IMAGE}"
docker push "${SA_DOCKER_IMAGE}"
oc import-image --insecure=true smart-gateway-operator:latest --from=$(oc registry info)/sa-telemetry/smart-gateway-operator --confirm
```

**NOTE:** The `--insecure=true` flag is to work around an issue where the
openshift internal registry is not trusted. It is expected we can drop it
in a future revision. See [minishift issue](https://github.com/minishift/minishift/issues/2544)
and [openshift issue](https://github.com/openshift/origin/issues/20604)

#### Deploy SAF

Follow the process for deploying SAF in a testing environment. Hints:

* [Travis automation](https://github.com/redhat-service-assurance/telemetry-framework/blob/master/.travis.yml#L12)
* [SAF Documentation](https://github.com/redhat-service-assurance/telemetry-framework/blob/master/deploy/README.md#quickstart-minishift)

NOTE: This process will cause a couple of expected errors while running the
`quickstart.sh` script in telemetry-framework:

* `Error from server (AlreadyExists): project.project.openshift.io "sa-telemetry" already exists`
  * It was created in order to stage the operator image
* `error: the tag "latest" points to "172.30.1.1:5000/sa-telemetry/smart-gateway-operator" - use the 'tag' command if you want to change the source to "quay.io/redhat-service-assurance/smart-gateway-operator:latest`
  * It was created in order to stage the operator image
* `Error from server (AlreadyExists): error when creating "operators/smartgateway/crds/smartgateway_v1alpha1_smartgateway_crd.yaml": customresourcedefinitions.apiextensions.k8s.io "smartgateways.smartgateway.infra.watch" already exists`
  * You may see this if you have been testing the operator prior to deploying it
    for integration with SAF

## Creating a Smart Gateway

Start a new smart gateway by creating a CustomResource object
based on the example:

```shell
oc create -f deploy/crds/smartgateway_v1alpha1_smartgateway_cr.yaml
```

Here is an example CustomResource for the `white` smart gateway.

```yaml
apiVersion: smartgateway.infra.watch/v1alpha1
kind: SmartGateway
metadata:
  name: white
spec:
  size: 1
```
