#! /bin/sh
PEAS_PROXY_LISTENING=true \
bundle exec puma config.ru \
-p 4080 \
--env ${PEAS_ENV:=development}
