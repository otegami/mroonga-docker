FROM debian:bookworm

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
      wget \
      locales \
      gosu \
      && rm -rf /var/lib/apt/lists/*

# Add Apache Arrow and Groonga repositories
RUN wget https://apache.jfrog.io/artifactory/arrow/debian/apache-arrow-apt-source-latest-bookworm.deb && \
    apt-get update && \
    apt-get install -y ./apache-arrow-apt-source-latest-bookworm.deb && \
    rm apache-arrow-apt-source-latest-bookworm.deb

RUN wget https://packages.groonga.org/debian/groonga-apt-source-latest-bookworm.deb && \
    apt-get update && \
    apt-get install -y ./groonga-apt-source-latest-bookworm.deb && \
    rm groonga-apt-source-latest-bookworm.deb

# Install MariaDB from Debian, Groonga/Mroonga libs, and tokenizer
RUN apt-get update && \
    apt-get install -y \
      mariadb-server \
      groonga \
      groonga-tokenizer-mecab \
      libgroonga0 \
      && rm -rf /var/lib/apt/lists/*

# Download and install Mroonga manually
RUN apt-get update && \
    apt-get download mariadb-10.11-mroonga && \
    dpkg --force-depends -i mariadb-10.11-mroonga*.deb && \
    rm mariadb-10.11-mroonga*.deb && \
    apt-get install -f -y && \
    rm -rf /var/lib/apt/lists/*

# Setup Japanese locale
RUN sed -i 's/^# *ja_JP.UTF-8/ja_JP.UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=ja_JP.UTF-8

# Copy custom configuration
COPY my.cnf /etc/mysql/conf.d/my.cnf

# Copy and setup entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Prepare Mroonga installation SQL
RUN mkdir -p /docker-entrypoint-initdb.d && \
    if [ -f /usr/share/mroonga/install.sql ]; then \
      cp /usr/share/mroonga/install.sql /docker-entrypoint-initdb.d/00-mroonga.sql; \
    else \
      echo "INSTALL SONAME 'ha_mroonga';" > /docker-entrypoint-initdb.d/00-mroonga.sql; \
    fi

VOLUME ["/var/lib/mysql"]

EXPOSE 3306

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["mysqld", "--bind-address=0.0.0.0"]
