#! /bin/sh
export PEAS_PROXY_LISTENING=true
bundle exec puma config.ru \
-p ${PEAS_PROXY_PORT:=4080} \
--env ${PEAS_ENV:=development}
