#!/bin/bash -x
cat << EOF | tee cfosimagepullsecret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: cfosimagepullsecret
data:
  .dockerconfigjson: $(echo -n '{"auths":{"fortinetwandy.azurecr.io":{"username":"00000000-0000-0000-0000-000000000000","password":"$accessToken","email":"wandy@example.com"}}}' | base64 -w 0)
type: kubernetes.io/dockerconfigjson
EOF

