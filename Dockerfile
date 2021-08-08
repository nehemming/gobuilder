FROM golang:1.16.6 as builder
RUN apt-get update && \
    apt-get install -yq \
        bash \
        ca-certificates \
        curl \
        git \
        gzip \
        locales \
        make \
        wget \
        xz-utils \
        zip 

# Upx 3.95 (as packaged) does not build macos binaries correctly
# so here wil will manually insttall
# its ok in builder as works for linux
RUN curl -L https://github.com/upx/upx/releases/download/v3.96/upx-3.96-amd64_linux.tar.xz \
        --output /tmp/upx-3.96-amd64_linux.tar.xz && \
    ls -l /tmp && \
    which xz && \
    tar -xf /tmp/upx-3.96-amd64_linux.tar.xz -C /tmp && \
    cp /tmp/upx-3.96-amd64_linux/upx /usr/local/bin

# Build hugo from source, slow 
# RUN git clone https://github.com/gohugoio/hugo.git && \
#     cd hugo && \
#     go install --tags extended && \
#     cd .. 

# install useful tool chain items
# each built sperately to allow caching
RUN go install -ldflags="-s -w" github.com/Songmu/gocredits/cmd/gocredits@latest
RUN go install -ldflags="-s -w" github.com/goreleaser/goreleaser@latest 
RUN go install -ldflags="-s -w" github.com/tcnksm/ghr@latest 
RUN go install -ldflags="-s -w" google.golang.org/protobuf/cmd/protoc-gen-go@latest 
RUN go install -ldflags="-s -w" github.com/caarlos0/svu@latest 
RUN go install -ldflags="-s -w" github.com/client9/misspell/cmd/misspell@latest
RUN go install -ldflags="-s -w" github.com/nehemming/cirocket@master 

RUN go install -ldflags="-s -w" golang.org/x/tools/cmd/cover@latest
RUN go install -ldflags="-s -w" github.com/mattn/goveralls@latest

RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.41.1

# build nancy from source
RUN git clone https://github.com/sonatype-nexus-community/nancy.git && \
    cd nancy && \
    make build && \
    cp nancy /go/bin && \
    cd ..

# compress the built binaries
RUN find /go/bin -maxdepth 1 -type f -executable -exec upx '{}' \;

# Download proto buffers
RUN mkdir -p /tmp/proto && \
    cd /tmp/proto && \
    wget https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-x86_64.zip && \
    unzip protoc-3.17.3-linux-x86_64.zip && \
    mv bin/protoc /go/bin

FROM circleci/golang:1.16
USER root
ARG REPO_USER=nehemming
ARG REPO_NAME=gobuilder
LABEL org.opencontainers.image.source https://github.com/$REPO_USER/$REPO_NAME
RUN apt-get update && \
    apt-get install -yq \
        bash \
        ca-certificates \
        curl \
        git \
        gnupg \
        gzip \
        locales \ 
        make \
        net-tools \
        openssh-client \
        parallel \
        sudo \
        tar \
        unzip \
        wget \
        zip && \
    curl -H 'Cache-Control: no-cache' https://raw.githubusercontent.com/fossas/fossa-cli/master/install.sh | bash

# Add hugo to the build, used for doocumentation
RUN curl -LO https://github.com/gohugoio/hugo/releases/download/v0.87.0/hugo_extended_0.87.0_Linux-64bit.deb && \
    dpkg -i hugo_extended_0.87.0_Linux-64bit.deb

COPY --from=builder /go/bin/ /go/bin
COPY --from=builder /usr/local/bin/upx /usr/local/bin/upx 
COPY --from=builder /tmp/proto/include /usr/include
USER circleci
ENTRYPOINT [ "/bin/bash" ]