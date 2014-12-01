#! /bin/sh
PEAS_API_LISTENING=true \
bundle exec puma config.ru \
-b 'ssl://0.0.0.0:4443?key=contrib/ssl-keys/server.key&cert=contrib/ssl-keys/server.crt' \
--env ${PEAS_ENV:=development}
