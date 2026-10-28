FROM nginxinc/nginx-unprivileged:1.31-alpine

# Rendered with envsubst at startup, so the API address can differ per environment
# (Compose service name, Kubernetes Service name...).
ENV API_UPSTREAM=http://api:3000
COPY default.conf.template /etc/nginx/templates/default.conf.template
COPY index.html /usr/share/nginx/html/index.html

EXPOSE 8080
