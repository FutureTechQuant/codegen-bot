#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUOYI_DIR="${ROOT_DIR}/ruoyi"

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PWD="${MYSQL_PWD:-root}"

CODEGEN_DB_NAME="${CODEGEN_DB_NAME:-ruoyi-vue-pro}"
CODEGEN_MODULE_NAME="${CODEGEN_MODULE_NAME:-}"
CODEGEN_TABLE_PREFIX="${CODEGEN_TABLE_PREFIX:-}"
CODEGEN_BASE_PACKAGE="${CODEGEN_BASE_PACKAGE:-cn.iocoder.yudao}"
CODEGEN_OUTPUT_DIR="${CODEGEN_OUTPUT_DIR:-${ROOT_DIR}/out/generated}"

DB_URL="${DB_URL:-jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${CODEGEN_DB_NAME}?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true&rewriteBatchedStatements=true&nullCatalogMeansCurrent=true}"
DB_USER="${DB_USER:-${MYSQL_USER}}"
DB_PWD="${DB_PWD:-${MYSQL_PWD}}"

mysql_exec() {
  MYSQL_PWD="${MYSQL_PWD}" mysql \
    -h"${MYSQL_HOST}" \
    -P"${MYSQL_PORT}" \
    -u"${MYSQL_USER}" \
    --default-character-set=utf8mb4 \
    "$@"
}

echo "== prepare output dir =="
rm -rf "${CODEGEN_OUTPUT_DIR}"
mkdir -p "${CODEGEN_OUTPUT_DIR}"

echo "== recreate database ${CODEGEN_DB_NAME} =="
mysql_exec -e "DROP DATABASE IF EXISTS \`${CODEGEN_DB_NAME}\`;"
mysql_exec -e "CREATE DATABASE \`${CODEGEN_DB_NAME}\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

echo "== import ruoyi base sql =="
BASE_SQL="${RUOYI_DIR}/sql/mysql/ruoyi-vue-pro.sql"
if [[ ! -f "${BASE_SQL}" ]]; then
  echo "ERROR: missing base sql: ${BASE_SQL}"
  exit 1
fi
mysql_exec "${CODEGEN_DB_NAME}" < "${BASE_SQL}"

echo "== snapshot base tables =="
mapfile -t BASE_TABLES < <(
  mysql_exec -N -B -e "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = '${CODEGEN_DB_NAME}'
      AND table_type = 'BASE TABLE'
    ORDER BY table_name
  "
)

echo "== import business sql from this repo =="
SQL_ROOT="${ROOT_DIR}/sql/schema"
if [[ ! -d "${SQL_ROOT}" ]]; then
  echo "ERROR: missing business sql dir: ${SQL_ROOT}"
  exit 1
fi

mapfile -t SQL_FILES < <(find "${SQL_ROOT}" -type f -name '*.sql' | sort)

if [[ ${#SQL_FILES[@]} -eq 0 ]]; then
  echo "ERROR: no sql files found under ${SQL_ROOT}"
  exit 1
fi

for f in "${SQL_FILES[@]}"; do
  echo "import -> ${f}"
  mysql_exec "${CODEGEN_DB_NAME}" < "${f}"
done

echo "== snapshot all tables after business import =="
mapfile -t ALL_TABLES < <(
  mysql_exec -N -B -e "
    SELECT table_name
    FROM information_schema.tables
    WHERE table_schema = '${CODEGEN_DB_NAME}'
      AND table_type = 'BASE TABLE'
    ORDER BY table_name
  "
)

echo "== detect newly added business tables =="
declare -A BASE_TABLE_SET=()
for t in "${BASE_TABLES[@]}"; do
  BASE_TABLE_SET["$t"]=1
done

NEW_TABLES=()
for t in "${ALL_TABLES[@]}"; do
  if [[ -z "${BASE_TABLE_SET[$t]+x}" ]]; then
    NEW_TABLES+=("$t")
  fi
done

if [[ ${#NEW_TABLES[@]} -eq 0 ]]; then
  echo "ERROR: no new business tables detected after importing ${SQL_ROOT}"
  exit 1
fi

printf 'new table -> %s\n' "${NEW_TABLES[@]}"

if [[ -z "${CODEGEN_TABLE_PREFIX}" ]]; then
  PREFIXES=()
  declare -A PREFIX_SEEN=()

  for t in "${NEW_TABLES[@]}"; do
    prefix="${t%%_*}"
    if [[ "${prefix}" == "${t}" ]]; then
      echo "ERROR: cannot infer table prefix from table without underscore: ${t}"
      exit 1
    fi
    prefix="${prefix}_"
    if [[ -z "${PREFIX_SEEN[$prefix]+x}" ]]; then
      PREFIX_SEEN["$prefix"]=1
      PREFIXES+=("$prefix")
    fi
  done

  if [[ ${#PREFIXES[@]} -ne 1 ]]; then
    echo "ERROR: multiple table prefixes detected from sql/schema: ${PREFIXES[*]}"
    echo "Please set CODEGEN_TABLE_PREFIX explicitly."
    exit 1
  fi

  CODEGEN_TABLE_PREFIX="${PREFIXES[0]}"
fi

if [[ -z "${CODEGEN_MODULE_NAME}" ]]; then
  CODEGEN_MODULE_NAME="${CODEGEN_TABLE_PREFIX%_}"
fi

export DB_URL DB_USER DB_PWD
export CODEGEN_DB_NAME CODEGEN_OUTPUT_DIR CODEGEN_MODULE_NAME CODEGEN_TABLE_PREFIX CODEGEN_BASE_PACKAGE

echo "== resolved codegen config =="
echo "CODEGEN_MODULE_NAME=${CODEGEN_MODULE_NAME}"
echo "CODEGEN_TABLE_PREFIX=${CODEGEN_TABLE_PREFIX}"

echo "== check all tables count =="
mysql_exec -e "
  SELECT COUNT(*) AS cnt
  FROM information_schema.tables
  WHERE table_schema = '${CODEGEN_DB_NAME}'
    AND table_type = 'BASE TABLE'
" || true

ESCAPED_PREFIX="${CODEGEN_TABLE_PREFIX//_/\\_}"

echo "== check prefixed tables count =="
mysql_exec -e "
  SELECT table_name
  FROM information_schema.tables
  WHERE table_schema = '${CODEGEN_DB_NAME}'
    AND table_type = 'BASE TABLE'
    AND table_name LIKE '${ESCAPED_PREFIX}%'
  ORDER BY table_name
" || true

echo "== install integration test into ruoyi =="
mkdir -p "${RUOYI_DIR}/yudao-server/src/test/java/ci/codegen"
mkdir -p "${RUOYI_DIR}/yudao-server/src/test/resources"

cp "${ROOT_DIR}/tools/codegen/CiCodegenIT.java" \
   "${RUOYI_DIR}/yudao-server/src/test/java/ci/codegen/CiCodegenIT.java"

cp "${ROOT_DIR}/tools/codegen/application-ci-codegen.yaml" \
   "${RUOYI_DIR}/yudao-server/src/test/resources/application-ci-codegen.yaml"

echo "== override ruoyi codegen templates =="

LOCAL_TPL_DIR="${ROOT_DIR}/tools/codegen/templates"
RUOYI_TPL_DIR="${RUOYI_DIR}/yudao-module-infra/src/main/resources/codegen"

if [[ ! -d "${RUOYI_TPL_DIR}" ]]; then
  echo "ERROR: ruoyi codegen template dir not found: ${RUOYI_TPL_DIR}"
  exit 1
fi

if [[ -f "${LOCAL_TPL_DIR}/java/enums/errorcode.vm" ]]; then
  mkdir -p "${RUOYI_TPL_DIR}/java/enums"
  cp "${LOCAL_TPL_DIR}/java/enums/errorcode.vm" \
     "${RUOYI_TPL_DIR}/java/enums/errorcode.vm"
  echo "overridden: ${RUOYI_TPL_DIR}/java/enums/errorcode.vm"
else
  echo "WARN: local errorcode.vm not found at ${LOCAL_TPL_DIR}/java/enums/errorcode.vm"
fi

echo "== verify copied files =="
ls -l "${RUOYI_DIR}/yudao-server/src/test/java/ci/codegen/CiCodegenIT.java"
ls -l "${RUOYI_DIR}/yudao-server/src/test/resources/application-ci-codegen.yaml"

echo "== patch yudao-server pom with test deps =="
python3 - <<'PY'
from pathlib import Path

pom = Path("ruoyi/yudao-server/pom.xml")
text = pom.read_text(encoding="utf-8")

marker = "</dependencies>"
block = """
        <!-- added by future-codegen-bot for CI integration test -->
        <dependency>
            <groupId>org.springframework.boot</groupId>
            <artifactId>spring-boot-starter-test</artifactId>
            <scope>test</scope>
        </dependency>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <scope>test</scope>
        </dependency>
"""

if "spring-boot-starter-test" not in text:
    if marker not in text:
        raise SystemExit("ERROR: </dependencies> not found in yudao-server/pom.xml")
    text = text.replace(marker, block + "\n    " + marker, 1)
    pom.write_text(text, encoding="utf-8")
PY

echo "== verify pom patch =="
grep -n "spring-boot-starter-test\|junit-jupiter" "${RUOYI_DIR}/yudao-server/pom.xml" || true

echo "== run codegen integration test =="
cd "${RUOYI_DIR}"
if ! mvn -pl yudao-server -am \
  -Dtest=ci.codegen.CiCodegenIT \
  -Dsurefire.failIfNoSpecifiedTests=false \
  test; then
  echo "== surefire reports =="
  find yudao-server/target/surefire-reports -maxdepth 1 -type f | sort | while read -r f; do
    echo "--------------------------------------------------"
    echo "FILE: $f"
    echo "--------------------------------------------------"
    sed -n '1,240p' "$f" || true
  done
  exit 1
fi

echo "== clone admin controllers to app controllers =="
APP_KEEP_HTTP_METHODS="${APP_KEEP_HTTP_METHODS:-GET}" \
APP_KEEP_METHOD_NAMES="${APP_KEEP_METHOD_NAMES:-}" \
python3 "${ROOT_DIR}/tools/codegen/clone_admin_controller_to_app.py" \
  --generated-dir "${CODEGEN_OUTPUT_DIR}"

echo "== generated files =="
find "${CODEGEN_OUTPUT_DIR}" -type f | sort || true

if ! find "${CODEGEN_OUTPUT_DIR}" -type f | grep -q .; then
  echo "ERROR: no generated files under ${CODEGEN_OUTPUT_DIR}"
  exit 1
fi
