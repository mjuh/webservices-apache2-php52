mkdir -p trash
cd trash
docker save docker-registry.intr/webservices/apache2-php52:latest | tar xv --wildcards '*/layer.tar' | tee /tmp/tempstore  | xargs -n1 -I{} tar xvf {}
cat /tmp/tempstore | xargs rm -rf
find . -empty -type d -delete

