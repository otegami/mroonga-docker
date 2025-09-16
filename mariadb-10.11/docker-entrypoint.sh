#!/bin/bash
set -eo pipefail

# If command starts with an option, prepend mysqld
if [ "${1:0:1}" = '-' ]; then
	set -- mysqld "$@"
fi

# Initialize database if not exists
if [ "$1" = 'mysqld' ] && [ ! -d "/var/lib/mysql/mysql" ]; then
	echo 'Initializing database...'
	mysql_install_db --user=mysql --datadir=/var/lib/mysql --rpm
	echo 'Database initialized'

	# Start temporary server
	echo 'Starting temporary server for setup...'
	"$@" --skip-networking --socket=/var/run/mysqld/mysqld.sock &
	pid="$!"

	# Wait for server to start
	for i in {1..30}; do
		if mysql --protocol=socket -uroot --socket=/var/run/mysqld/mysqld.sock --execute "SELECT 1" &> /dev/null; then
			break
		fi
		echo 'Waiting for server to start...'
		sleep 1
	done

	if [ "$i" = 30 ]; then
		echo >&2 'Failed to start server for initialization'
		exit 1
	fi

	# Set root password if provided
	if [ -n "$MYSQL_ROOT_PASSWORD" ]; then
		mysql --protocol=socket -uroot --socket=/var/run/mysqld/mysqld.sock <<-EOSQL
			SET @@SESSION.SQL_LOG_BIN=0;
			DELETE FROM mysql.user WHERE user NOT IN ('mysql.sys', 'mariadb.sys', 'mysqlxsys', 'root') OR host NOT IN ('localhost');
			SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}');
			GRANT ALL ON *.* TO 'root'@'localhost' WITH GRANT OPTION;
			CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '${MYSQL_ROOT_PASSWORD}';
			GRANT ALL ON *.* TO 'root'@'%' WITH GRANT OPTION;
			DROP DATABASE IF EXISTS test;
			DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
			FLUSH PRIVILEGES;
		EOSQL
	fi

	# Create database if specified
	if [ -n "$MYSQL_DATABASE" ]; then
		echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" --socket=/var/run/mysqld/mysqld.sock
	fi

	# Create user if specified
	if [ -n "$MYSQL_USER" ] && [ -n "$MYSQL_PASSWORD" ]; then
		echo "CREATE USER IF NOT EXISTS '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" --socket=/var/run/mysqld/mysqld.sock

		if [ -n "$MYSQL_DATABASE" ]; then
			echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* TO '$MYSQL_USER'@'%';" | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" --socket=/var/run/mysqld/mysqld.sock
		fi

		echo "FLUSH PRIVILEGES;" | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" --socket=/var/run/mysqld/mysqld.sock
	fi

	# Install Mroonga plugin and run init scripts
	echo 'Installing Mroonga plugin...'
	for f in /docker-entrypoint-initdb.d/*; do
		if [ -f "$f" ]; then
			case "$f" in
				*.sh)
					echo "Running $f"
					. "$f"
					;;
				*.sql)
					echo "Running $f"
					mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" --socket=/var/run/mysqld/mysqld.sock < "$f"
					;;
				*.sql.gz)
					echo "Running $f"
					gunzip -c "$f" | mysql --protocol=socket -uroot -p"${MYSQL_ROOT_PASSWORD}" --socket=/var/run/mysqld/mysqld.sock
					;;
				*)
					echo "Ignoring $f"
					;;
			esac
		fi
	done

	# Stop temporary server
	if ! kill -s TERM "$pid" || ! wait "$pid"; then
		echo >&2 'Failed to stop temporary server'
		exit 1
	fi

	echo 'MariaDB init process done. Ready for start up.'
fi

# Create socket directory if it doesn't exist
mkdir -p /var/run/mysqld
chown mysql:mysql /var/run/mysqld

# Execute the command as mysql user
exec gosu mysql "$@"