#!/usr/bin/env bash
PACKAGE="nexmo-istio-tlsproxy"
#REPO_ID=564623767830
REGION="eu-west-1"

AWS_REGION=${REGION}
AWS_DEFAULT_REGION=${REGION}

REPO=${REPO_ID}.dkr.ecr.${REGION}.amazonaws.com

IMAGE=${REPO}/${PACKAGE}

version=`cat .version`
if [[ -z "${version}" ]]; then
    echo "Could not determine version, aborting."
    exit 1
fi

echo "+--- Version checks"
echo "| Docker: $(docker --version)"
echo "| Kubectl: $(kubectl version --short --client)"
echo "| AWS cli: $(aws --version)"

# suppress a legal -e flag that docker no longer supports
docker_login=$(aws ecr get-login --region ${REGION} | sed 's/ -e none//')
echo "Logging into Dev ECR"
eval ${docker_login}

regversion=$(aws ecr describe-images --registry-id ${REPO_ID}  --repository-name ${PACKAGE} --query 'sort_by(imageDetails,& imagePushedAt)[-1].imageTags' | grep -e [0-9] | sed 's/[ ",]//g' )

echo "Git repo version: $version"
echo "Registry latest version: ${regversion}"

if [[ "${version}" = "${regversion}" ]]; then 
  echo "Version ${version} already exists in registry - did you remember to bump the version?"
else
    docker build . -t $IMAGE:$version
    docker tag $IMAGE:$version $IMAGE:latest

    echo "Preparing to publish ${IMAGE}:${version} to ${IMAGE}:${version}"

#    docker tag $IMAGE:latest $IMAGE:latest
#    docker tag $IMAGE:$version $IMAGE:$version
    docker push $IMAGE:latest
    docker push $IMAGE:$version

    echo "Deploying ${IMAGE}:${version}"
    kubectx istio-dev
    patchstr="{\"spec\": {\"template\": {\"spec\": {\"containers\": [{\"name\": \"tlsproxy\", \"image\": \"${IMAGE}:${version}\"}]}}}}"
    echo Patching: ${patchstr} to istio-dev
    AWS_PROFILE=nexmo-dev kubectl patch deployment tlsproxy -n nexmo-k8s -p \ "${patchstr}"
fi
