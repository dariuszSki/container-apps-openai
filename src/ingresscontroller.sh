kubectl create namespace ingress-basic

helm upgrade --install $INGRESS_NAME ingress-nginx --version 3.36.0 --namespace $NAMESPACE \
--set controller.replicaCount=2 \
--set controller.nodeSelector."kubernetes\.io/os"=linux \
--set controller.image.registry=$ACR_URL \
--set controller.image.image=$CONTROLLER_IMAGE \
--set controller.image.tag=$CONTROLLER_TAG  \
--set controller.image.digest="" \
--set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
--set controller.admissionWebhooks.patch.image.registry=$ACR_URL \
--set controller.admissionWebhooks.patch.image.digest="" \
--set controller.admissionWebhooks.patch.image.image=$PATCH_IMAGE \
--set controller.admissionWebhooks.patch.image.tag=$PATCH_TAG \
--set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
--set defaultBackend.image.registry=$ACR_URL \
--set defaultBackend.image.image=$DEFAULTBACKEND_IMAGE \
--set defaultBackend.image.tag=$DEFAULTBACKEND_TAG \
--set defaultBackend.image.digest="" \
-f internal-ingress.yaml

kubectl create namespace ingress

helm install openai-apps-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 0.18.1 --namespace ingress \
--set controller.replicaCount=2 \
--set controller.nodeSelector."kubernetes\.io/os"=linux \
--set controller.admissionWebhooks.patch.nodeSelector."kubernetes\.io/os"=linux \
--set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
-f ingress-value.yml


helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 0.18.1


helm install openai-apps-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 0.18.1 --namespace ingress --set controller.replicaCount=1 -f ingress-value.yml


helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --set installCRDs=true

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm update
helm install ingress-controller ingress-nginx/ingress-nginx

echo | openssl s_client -showcerts -servername chatapp.dariuszski.dev -connect chatapp.dariuszski.dev:443 2>/dev/null | openssl x509 -inform pem -noout -text








helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx 
helm repo update

helm install openai-apps-ingress ingress-nginx/ingress-nginx --create-namespace --namespace chatbot

helm --namespace chatbot install openai-apps-ingress ingress-nginx/ingress-nginx  \
--set controller.ingressClass=chatbot \
--set controller.replicaCount=1 \
--set controller.nodeSelector."kubernetes\.io/os"=linux \
--set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
--set controller.config.hsts='"true"' \
--set controller.config.hsts-include-subdomains='"true"' \
--set controller.config.hsts-preload='"true"' \
--set controller.config.use-http2='"true"' \
--set controller.config.hsts-max-age='"63072000"' \
--set controller.service.externalTrafficPolicy=Local --debug \
--set controller.ingressClassResource.name=chatbot \
--set controller.ingressClassResource.controllerValue="k8s.io/chatbot" \
--set controller.service.beta.kubernetes.io/azure-load-balancer-internal="true"



apiVersion: networking.k8s.io/v1
  kind: Ingress
  metadata:
    name: example
    namespace: foo
  spec:
    ingressClassName: chatbot
    rules:
      - host: www.example.com
        http:
          paths:
            - pathType: Prefix
              backend:
                service:
                  name: exampleService
                  port:
                    number: 80
              path: /
    # This section is only required if TLS is to be enabled for the Ingress
    tls:
      - hosts:
        - www.example.com
        secretName: example-tls

If TLS is enabled for the Ingress, a Secret containing the certificate and key must also be provided:

  apiVersion: v1
  kind: Secret
  metadata:
    name: example-tls
    namespace: foo
  data:
    tls.crt: <base64 encoded cert>
    tls.key: <base64 encoded key>
  type: kubernetes.io/tls