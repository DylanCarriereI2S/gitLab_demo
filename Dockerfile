FROM golang:alpine

ENV TERRAFORM_VERSION=1.0.0

RUN apk add --update git bash openssh npm

ENV TF_DEV=true
ENV TF_RELEASE=true

WORKDIR $GOPATH/src/github.com/hashicorp/terraform
RUN git clone https://github.com/hashicorp/terraform.git ./ && \
    git checkout v${TERRAFORM_VERSION} && \
    /bin/bash scripts/build.sh

RUN npm install -g @angular/cli@12.2.1

WORKDIR /code