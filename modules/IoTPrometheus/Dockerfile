
FROM prom/prometheus:v2.30.2

USER root
 
RUN wget https://github.com/quantumew/mustache-cli/releases/download/v1.0.0/mustache-cli-linux-amd64.zip && \
    unzip mustache-cli-linux-amd64.zip && \
    mkdir -p -m 775 /usr/local/bin && \
    mv mustache /usr/local/bin/mustache


ENV SERVER_URL='http://40.64.90.105/api/v1/write'
ENV METRICS-ENDPOINTS="[edgeAgent:9600, edgeHub:9600]"

COPY config-template.yml /prometheus/
COPY start.sh /prometheus/

ENTRYPOINT /prometheus/start.sh
