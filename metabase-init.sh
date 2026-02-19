#!/bin/sh
set -e
MB_URL="http://localhost:3000"
su -s /bin/sh metabase -c "java -jar /home/metabase/metabase.jar &"
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
          "db": "'"$STARROCKS_DATABASE"'",
          "user": "'"$STARROCKS_USER"'",
          "password": "'"$STARROCKS_PASSWORD"'"
        },
        "is_on_demand": false,
        "refingerprint": true
      }
    }' >/dev/null
else
  SESSION=$(curl -s -X POST "$MB_URL/api/session" -H "Content-Type: application/json" -d "{\"username\":\"$METABASE_ADMIN_EMAIL\",\"password\":\"$METABASE_ADMIN_PASSWORD\"}")
  TOKEN=$(echo "$SESSION" | jq -r '.id // empty')
  if [ -n "$TOKEN" ]; then
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
          "db": "'"$STARROCKS_DATABASE"'",
          "user": "'"$STARROCKS_USER"'",
          "password": "'"$STARROCKS_PASSWORD"'"
        },
        "is_on_demand": false,
        "refingerprint": true
      }' >/dev/null || true
  fi
fi
while [ -z "$PID" ]; do
  PID=$(pgrep -u metabase -f "/home/metabase/metabase.jar" || true)
  [ -n "$PID" ] || sleep 1
done
while kill -0 "$PID" 2>/dev/null; do
  sleep 60
done
