mustache ENV /prometheus/config-template.yml > /prometheus/config.yml

cat /prometheus/config.yml

/bin/prometheus \
--config.file=/prometheus/config.yml \
--storage.tsdb.path=/prometheus \
--web.console.libraries=/usr/share/prometheus/console_libraries \
--web.console.templates=/usr/share/prometheus/consoles
