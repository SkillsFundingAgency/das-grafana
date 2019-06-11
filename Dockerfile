FROM grafana/grafana:latest

COPY ./datasources/azure.datasource.yml /etc/grafana/provisioning/datasources/azure.datasource.yml
COPY ./custom.ini /etc/grafana/grafana.ini

ENV GF_INSTALL_PLUGINS=grafana-azure-monitor-datasource
