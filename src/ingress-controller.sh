
helm install nginx-ingress ingress-nginx/ingress-nginx\
  --create-namespace \
  --namespace ingress \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.replicaCount=1 \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal"=true \
  --set controller.service.loadBalancerIP="10.0.0.122" 
  # --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-internal-subnet"=ContainerApps
kubectl apply -f apps-deployment.yml
kubectl apply -f ingress.yml

docker run \
  -v '/var/lib/letsencrypt:/var/lib/letsencrypt' \
  -v '/etc/letsencrypt:/etc/letsencrypt' \
  --cap-drop=all \
  ghcr.io/aaomidi/certbot-dns-google-domains:latest \
  certbot certonly \
  --authenticator 'dns-google-domains' \
  --dns-google-domains-credentials '/var/lib/letsencrypt/dns_google_domains_credentials.ini' \
  --server 'https://acme-v02.api.letsencrypt.org/directory' \
  -d 'chatapp.dariuszski.dev' -m ynwa.lfc@dariuszski.dev --agree-tos

kubectl create secret tls chatapp --cert /etc/letsencrypt/live/chatapp.dariuszski.dev/cert.pem --key  /etc/letsencrypt/live/chatapp.dariuszski.dev/privkey.pem -n chatbot
kubectl create secret tls docapp --cert /etc/letsencrypt/live/docapp.dariuszski.dev/cert.pem --key  /etc/letsencrypt/live/docapp.dariuszski.dev/privkey.pem -n chatbot