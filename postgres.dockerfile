FROM postgres:18-alpine
COPY psql-multiple-postgres.sh /docker-entrypoint-initdb.d/