FROM httpd:2.4

ENV adminPass=admin
ENV SSLCountry=US
ENV SSLState=MD
ENV SSLLocation=Baltimore
Env SSLOrg=ModSec
ENV SSLCN=localhost

RUN apt-get update && apt-get -y install git cron
RUN cd /opt/ && \
    mkdir Waf2Py && \ 
    git clone https://github.com/ITSec-Chile/Waf2Py
    
RUN cd /opt/Waf2Py && \
    chmod +x Install.sh && \
    ./Install.sh

EXPOSE 62443
