FROM python:3-slim

RUN apt update
RUN apt install -y curl git
RUN apt install -y awscli
RUN curl -L https://oni.ca/runway/latest/linux -o /usr/local/bin/runway && chmod 755 /usr/local/bin/runway

ENV Vars to map:
AWS_ACCESS_KEY_ID
AWS_SECRET_ACCESS_KEY
AWS_SESSION_TOKEN
