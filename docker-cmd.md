## Build Dockerfile
`` 
docker build -t docker/terraform . 
``
## Run Docker Image
``
docker run --name terraform_dev --rm -v C:\Users\dcarriere\.aws:/root/.aws -v C:\Users\dcarriere\projects\gitlab_demo:/code -it  docker/terraform
``