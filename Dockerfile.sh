#!/bin/bash
cat <<EOF
FROM $BASE_IMAGE
MAINTAINER Andrey Mayorov <a.mayorov@rbkmoney.com>
COPY ./_build/prod/rel/party_management /opt/party_management
WORKDIR /opt/party_management
CMD /opt/party_management/bin/party_management foreground
EXPOSE 8022
LABEL com.rbkmoney.$SERVICE_NAME.parent=$BASE_IMAGE_NAME \
      com.rbkmoney.$SERVICE_NAME.parent_tag=$BASE_IMAGE_TAG \
      com.rbkmoney.$SERVICE_NAME.build_img=build \
      com.rbkmoney.$SERVICE_NAME.build_img_tag=$BUILD_IMAGE_TAG \
      com.rbkmoney.$SERVICE_NAME.commit_id=$(git rev-parse HEAD) \
      com.rbkmoney.$SERVICE_NAME.commit_number=$(git rev-list --count HEAD) \
      com.rbkmoney.$SERVICE_NAME.branch=$( \
        if [ "HEAD" != $(git rev-parse --abbrev-ref HEAD) ]; then \
          echo $(git rev-parse --abbrev-ref HEAD); \
        elif [ -n "$BRANCH_NAME" ]; then \
          echo $BRANCH_NAME; \
        else \
          echo $(git name-rev --name-only HEAD); \
        fi)
EOF
