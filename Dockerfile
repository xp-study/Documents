FROM squidfunk/mkdocs-material

ADD ./ /opt/Mkdocs

COPY ./templates/partials/header.html /usr/local/lib/python3.11/site-packages/material/templates/partials/

WORKDIR /opt/Mkdocs

EXPOSE 10000

ENTRYPOINT ["./run.sh"] 

