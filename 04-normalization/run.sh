#!/usr/bin/env bash
set -euo pipefail

case "$(uname -s)" in
    MINGW*|MSYS*) export MSYS_NO_PATHCONV=1 MSYS2_ARG_CONV_EXCL='*' ;;
    *) printf 'Run this lab in Git Bash.\n' >&2; exit 2 ;;
esac

cd "$(dirname "$0")"
container=mysql-labs-normalization-1
volume=mysql-labs-normalization-1-data
image=mysql:8.0.46
database=sales_norm
tag="SET @lab_session = 'normalization_1'"

mysql_cmd() {
    docker exec -i "$container" sh -c \
        'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysql --no-defaults -uroot --default-character-set=utf8mb4 "$@"' sh "$@"
}

check_owner() {
    local owner
    owner=$(docker inspect --format '{{index .Config.Labels "student.mysql-docker-labs"}}' "$container")
    [[ "$owner" == normalization-1 ]] || {
        printf 'The container %s belongs to another project.\n' "$container" >&2
        return 1
    }
}

start_lab() {
    if docker container inspect "$container" >/dev/null 2>&1; then
        check_owner
        docker start "$container"
    else
        if docker volume inspect "$volume" >/dev/null 2>&1; then
            printf 'Volume %s already exists. Use the container that owns it.\n' "$volume" >&2
            return 1
        fi
        local MYSQL_ROOT_PASSWORD
        MYSQL_ROOT_PASSWORD=$(openssl rand -hex 24)
        export MYSQL_ROOT_PASSWORD
        docker run --detach --name "$container" \
            --label student.mysql-docker-labs=normalization-1 \
            --env MYSQL_ROOT_PASSWORD \
            --mount "type=volume,source=$volume,target=/var/lib/mysql" \
            "$image" --general-log=ON --log-output=TABLE \
            --character-set-server=utf8mb4 --collation-server=utf8mb4_unicode_ci
    fi

    # MySQL's temporary initialization server accepts only socket connections.
    local attempt
    for ((attempt = 1; attempt <= 60; attempt++)); do
        if mysql_cmd --host=127.0.0.1 --batch --skip-column-names --execute='SELECT 1' >/dev/null 2>&1; then
            return
        fi
        sleep 2
    done
    docker logs --tail 25 "$container" >&2
    return 1
}

show_sql() {
    printf '\n=== %s ===\n' "$1"
    mysql_cmd --table --verbose "--init-command=$tag" < "$1"
}

dump_db() {
    local file=$1
    shift
    docker exec -i "$container" sh -c \
        'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysqldump --no-defaults -uroot --default-character-set=utf8mb4 --set-gtid-purged=OFF --single-transaction "$@"' \
        sh "$database" "$@" > "$file.tmp"
    test -s "$file.tmp"
    printf 'Дамп получен: %s\n' "$file"
}

export_log() {
    mysql_cmd --skip-column-names --batch --raw --execute="
        SELECT CONCAT(DATE_FORMAT(log.event_time, '%Y-%m-%d %H:%i:%s.%f'), '  ',
                      CASE WHEN log.command_type = 'Init DB' THEN 'USE ' ELSE '' END,
                      CONVERT(log.argument USING utf8mb4))
        FROM mysql.general_log AS log
        WHERE log.command_type IN ('Query', 'Init DB')
          AND log.thread_id IN (
              SELECT marker.thread_id FROM mysql.general_log AS marker
              WHERE marker.command_type = 'Query'
                AND CONVERT(marker.argument USING utf8mb4) = 'SET @lab_session = ''normalization_1'''
          )
          AND TRIM(CONVERT(log.argument USING utf8mb4)) <> ''
          AND CONVERT(log.argument USING utf8mb4) NOT REGEXP
              '^(SET @lab_session|SET NAMES|SET character_set_results|SELECT @@)'
        ORDER BY log.event_time" > my_actions.log.tmp
    grep -Fq 'CREATE TABLE sales_unnormalized_2' my_actions.log.tmp
    grep -Fq 'RENAME TABLE sales_unnormalized_2 TO sales_source_verified' my_actions.log.tmp
    printf 'Журнал экспортирован: my_actions.log\n'
}

run_lab() {
    start_lab
    local schema_count
    schema_count=$(mysql_cmd --batch --skip-column-names --execute="SELECT COUNT(*) FROM information_schema.SCHEMATA WHERE SCHEMA_NAME='$database'")
    if [[ "$schema_count" != 0 ]]; then
        printf 'База %s уже существует. Для демонстрации используйте bash run.sh connect.\n' "$database" >&2
        return 1
    fi
    printf '\n=== Среда выполнения ===\n'
    uname -sr
    docker ps --filter "name=^/$container$" --format '{{.Names}}  {{.Image}}  {{.Status}}'
    mysql_cmd --table "--init-command=$tag" \
        --execute='SELECT VERSION() AS mysql_version, @@global.general_log AS general_log, @@global.log_output AS log_output;'
    show_sql 01_source.sql
    show_sql 02_anomalies.sql
    dump_db dump_before.sql
    show_sql 03_normalize.sql
    local verification
    verification=$(show_sql 04_verify.sql)
    printf '%s\n' "$verification"
    grep -Eq '^[|][[:space:]]+1[[:space:]]+[|]$' <<< "$verification"
    show_sql 05_after.sql
    dump_db dump_after.sql customers products reports report_items
    export_log
    printf '\nИтог: проверки нормализации пройдены.\n'
}

case "${1:-}" in
    start) start_lab ;;
    run)
        run_lab 2>&1 | tee verification.txt.tmp
        for file in verification.txt dump_before.sql dump_after.sql my_actions.log; do
            mv -- "$file.tmp" "$file"
        done
        ;;
    connect)
        check_owner
        docker exec -it "$container" sh -c \
            'export MYSQL_PWD="$MYSQL_ROOT_PASSWORD"; exec mysql --no-defaults -uroot --default-character-set=utf8mb4 "$@"' sh "$database"
        ;;
    *) printf 'Usage: bash run.sh {start|run|connect}\n' >&2; exit 2 ;;
esac
