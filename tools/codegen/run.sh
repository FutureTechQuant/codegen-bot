#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUOYI_DIR="${ROOT}/ruoyi"
SQL_DIR="${ROOT}/sql/schema"
OUT_DIR="${ROOT}/out/generated"

MYSQL_HOST="${MYSQL_HOST:-127.0.0.1}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"
MYSQL_PWD="${MYSQL_PWD:-root}"

# 可选：消除 “Using a password on the command line…” 警告
MYCNF="${ROOT}/.tmp.my.cnf"
cat > "${MYCNF}" <<EOF
[client]
host=${MYSQL_HOST}
port=${MYSQL_PORT}
user=${MYSQL_USER}
password=${MYSQL_PWD}
EOF
chmod 600 "${MYCNF}"
mysql_base=(mysql --defaults-file="${MYCNF}")

cd "${RUOYI_DIR}"

ENGINE_FILE="$(git ls-files | grep -E '/CodegenEngine\.java$' | head -n 1 || true)"
if [[ -z "${ENGINE_FILE}" ]]; then
  echo "ERROR: CodegenEngine.java not found in ruoyi repo"
  exit 10
fi

MODULE_DIR="${ENGINE_FILE%%/src/main/java/*}"
ENGINE_PKG="$(grep -E '^package ' "${ENGINE_FILE}" | head -n1 | sed -E 's/package ([^;]+);/\1/')"
ENGINE_CLASS="${ENGINE_PKG}.CodegenEngine"

if [[ -z "${MODULE_DIR}" || -z "${ENGINE_PKG}" ]]; then
  echo "ERROR: cannot parse module/package from ${ENGINE_FILE}"
  exit 11
fi

echo "ENGINE_FILE=${ENGINE_FILE}"
echo "MODULE_DIR=${MODULE_DIR}"
echo "ENGINE_CLASS=${ENGINE_CLASS}"

# 把测试类从本仓库 copy 到 ruoyi 的目标模块
TEST_DIR="${RUOYI_DIR}/${MODULE_DIR}/src/test/java/ci/codegen"
mkdir -p "${TEST_DIR}"
cp -f "${ROOT}/tools/codegen/CiCodegenTest.java" "${TEST_DIR}/CiCodegenTest.java"

mkdir -p "${OUT_DIR}"
shopt -s nullglob
sql_files=("${SQL_DIR}"/*.sql)
if [[ ${#sql_files[@]} -eq 0 ]]; then
  echo "ERROR: no sql files in ${SQL_DIR}"
  exit 20
fi

"${mysql_base[@]}" -e "SELECT 1" >/dev/null

for f in "${sql_files[@]}"; do
  module="$(basename "${f}" .sql)"
  db="codegen_${module}"
  echo "==> module=${module}, db=${db}, sql=${f}"

  "${mysql_base[@]}" -e "DROP DATABASE IF EXISTS \`${db}\`; CREATE DATABASE \`${db}\` DEFAULT CHARACTER SET utf8mb4;"
  "${mysql_base[@]}" "${db}" < "${f}"

  export DB_URL="jdbc:mysql://${MYSQL_HOST}:${MYSQL_PORT}/${db}?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true"
  export DB_USER="${MYSQL_USER}"
  export DB_PWD="${MYSQL_PWD}"
  export CODEGEN_MODULE_NAME="${module}"
  export CODEGEN_ENGINE_CLASS="${ENGINE_CLASS}"
  export CODEGEN_OUTPUT_DIR="${ROOT}/out/generated/${module}"

  rm -rf "${CODEGEN_OUTPUT_DIR}" && mkdir -p "${CODEGEN_OUTPUT_DIR}"

  # 1) 先编译依赖，不跑测试
  mvn -q -f "${RUOYI_DIR}/pom.xml" -pl "${MODULE_DIR}" -am -DskipTests package

  # 2) 只在目标模块里跑我们这一个测试；并允许“其它模块没匹配到该测试”不报错
  mvn -q -f "${RUOYI_DIR}/pom.xml" -pl "${MODULE_DIR}" \
    -Dtest=ci.codegen.CiCodegenTest \
    -Dsurefire.failIfNoSpecifiedTests=false \
    test
done

rm -f "${MYCNF}"
echo "Generated under ${ROOT}/out/generated"
