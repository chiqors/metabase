#!/bin/sh
set -e
MB_URL="http://localhost:3000"
/opt/java/openjdk/bin/java -jar /home/metabase/metabase.jar &
PID=""
STATUS=""
while [ "$STATUS" != "ok" ]; do
  sleep 3
  STATUS=$(curl -s "$MB_URL/api/health" | jq -r '.status' 2>/dev/null || echo "")
done
SETUP_TOKEN=$(curl -s "$MB_URL/api/session/properties" | jq -r '.["setup-token"] // empty')
if [ -n "$SETUP_TOKEN" ]; then
  curl -s -X POST "$MB_URL/api/setup" \
    -H "Content-Type: application/json" \
    -d '{
      "token": "'"$SETUP_TOKEN"'",
      "user": { "first_name": "Admin", "last_name": "User", "email": "'"$METABASE_ADMIN_EMAIL"'", "password": "'"$METABASE_ADMIN_PASSWORD"'" },
      "prefs": { "site_name": "Metabase" },
      "database": {
        "engine": "starrocks",
        "name": "StarRocks",
        "details": {
          "host": "'"$STARROCKS_HOST"'",
          "port": '"$STARROCKS_PORT"',
          "catalog": "'"$STARROCKS_CATALOG"'",
          "dbname": "'"$STARROCKS_DATABASE"'",
          "user": "'"$STARROCKS_USER"'",
          "password": "'"$STARROCKS_PASSWORD"'"
        },
        "is_on_demand": false,
        "refingerprint": true
      }
    }' >/dev/null
fi
# Always ensure StarRocks exists and has db filled
TOKEN=$(curl -s -X POST "$MB_URL/api/session" -H "Content-Type: application/json" -d "{\"username\":\"$METABASE_ADMIN_EMAIL\",\"password\":\"$METABASE_ADMIN_PASSWORD\"}" | jq -r '.id // empty')
if [ -n "$TOKEN" ]; then
  DBLIST=$(curl -s "$MB_URL/api/database" -H "X-Metabase-Session: $TOKEN")
  SR_ID=$(echo "$DBLIST" | jq -r '.data[] | select(.engine=="starrocks") | .id' | head -n1)
  if [ -z "$SR_ID" ]; then
    curl -s -X POST "$MB_URL/api/database" \
      -H "Content-Type: application/json" \
      -H "X-Metabase-Session: $TOKEN" \
      -d '{
        "engine": "starrocks",
        "name": "StarRocks",
        "details": {
          "host": "'"$STARROCKS_HOST"'",
          "port": '"$STARROCKS_PORT"',
          "catalog": "'"$STARROCKS_CATALOG"'",
          "dbname": "'"$STARROCKS_DATABASE"'",
          "user": "'"$STARROCKS_USER"'",
          "password": "'"$STARROCKS_PASSWORD"'"
        },
        "is_on_demand": false,
        "refingerprint": true
      }' >/dev/null || true
  else
    SR_DB=$(echo "$DBLIST" | jq -r '.data[] | select(.engine=="starrocks") | (.details.dbname // .details.db // .details.database // empty)' | head -n1)
    if [ -z "$SR_DB" ] && [ -n "$STARROCKS_DATABASE" ]; then
      curl -s -X PUT "$MB_URL/api/database/$SR_ID" \
        -H "Content-Type: application/json" \
        -H "X-Metabase-Session: $TOKEN" \
        -d '{
          "engine": "starrocks",
          "name": "StarRocks",
          "details": {
            "host": "'"$STARROCKS_HOST"'",
            "port": '"$STARROCKS_PORT"',
            "catalog": "'"$STARROCKS_CATALOG"'",
            "dbname": "'"$STARROCKS_DATABASE"'",
            "user": "'"$STARROCKS_USER"'",
            "password": "'"$STARROCKS_PASSWORD"'"
          },
          "is_on_demand": false,
          "refingerprint": true
        }' >/dev/null
    fi
  fi
fi
while [ -z "$PID" ]; do
  PID=$(pgrep -u metabase -f "/home/metabase/metabase.jar" || true)
  [ -n "$PID" ] || sleep 1
done
while kill -0 "$PID" 2>/dev/null; do
  sleep 60
done
