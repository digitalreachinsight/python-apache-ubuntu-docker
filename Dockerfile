# Prepare the base environment.
FROM ubuntu:20.04 as builder_base_docker
MAINTAINER itadmin@digitalreach.com.au 
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Australia/Perth
ENV PRODUCTION_EMAIL=True
ENV SECRET_KEY="ThisisNotRealKey"
RUN apt-get clean
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install --no-install-recommends -y  wget git libmagic-dev gcc binutils libproj-dev gdal-bin python3 python3-setuptools python3-dev python3-pip tzdata cron rsyslog apache2 
RUN apt-get install --no-install-recommends -y libpq-dev
RUN apt-get install --no-install-recommends -y postfix libsasl2-modules
RUN apt-get install -y vim
# Example Self Signed Cert
RUN apt-get install -y openssl
RUN openssl req -new -newkey rsa:4096 -days 3650 -nodes -x509 -subj  "/C=AU/ST=Western Australia/L=Perth/O=Digital Reach Insight/OU=IT Department/CN=example.com"  -keyout /etc/ssl/private/selfsignedssl.key -out /etc/ssl/private/selfsignedssl.crt
#RUN apt-get install -y openssl && \
#    openssl genrsa -des3 -passout pass:x -out /etc/ssl/private/server.pass.key 2048 && \
#    openssl rsa -passin pass:x -in /etc/ssl/private/server.pass.key -out /etc/ssl/private/server.key && \
#    rm /etc/ssl/private/server.pass.key && \
#    openssl req -new -key /etc/ssl/private/server.key -out /etc/ssl/private/server.csr \
#        -subj "/C=AU/ST=Western Australia/L=Perth/O=Digital Reach Insight/OU=IT Department/CN=example.com" && \
#    openssl x509 -req -days 365 -in /etc/ssl/private/server.csr -signkey /etc/ssl/private/server.key -out /etc/ssl/private/server.crt
# Example Self Signed Cert


RUN ln -s /usr/bin/python3 /usr/bin/python && \
    ln -s /usr/bin/pip3 /usr/bin/pip
RUN pip install --upgrade pip

# Install Python libs from requirements.txt.
FROM builder_base_docker as python_libs_docker
WORKDIR /app
COPY requirements.txt ./
#RUN pip3 install --no-cache-dir -r requirements.txt \
  # Update the Django <1.11 bug in django/contrib/gis/geos/libgeos.py
  # Reference: https://stackoverflow.com/questions/18643998/geodjango-geosexception-error
  #&& sed -i -e "s/ver = geos_version().decode()/ver = geos_version().decode().split(' ')[0]/" /usr/local/lib/python3.8/dist-packages/django/contrib/gis/geos/libgeos.py \
#  && rm -rf /var/lib/{apt,dpkg,cache,log}/ /tmp/* /var/tmp/*
RUN apt-get install --no-install-recommends -y libapache2-mod-wsgi-py3 virtualenv
# Install the project (ensure that frontend projects have been built prior to this step).
FROM python_libs_docker
#COPY gunicorn.ini manage.py ./
# Set  local perth time
COPY timezone /etc/timezone
ENV TZ=Australia/Perth
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

COPY sites.conf /etc/apache2/sites-enabled/
RUN mkdir /etc/webconfs/
RUN mkdir /etc/webconfs/apache/ 
RUN mkdir /var/web/
RUN mkdir /etc/postfix-conf/
RUN a2enmod ssl

RUN touch /app/.env
COPY boot.sh /
#RUN python manage.py collectstatic --noinput
#RUN service rsyslog start
#RUN chmod 0644 /etc/cron.d/dockercron
#RUN crontab /etc/cron.d/dockercron
#RUN touch /var/log/cron.log
#RUN service cron start
RUN touch /etc/cron.d/dockercron
RUN cron /etc/cron.d/dockercron
RUN chmod 755 /boot.sh
EXPOSE 80
#HEALTHCHECK --interval=1m --timeout=5s --start-period=10s --retries=3 CMD ["wget", "-q", "-O", "-", "http://localhost:8080/"]
HEALTHCHECK --interval=5s --timeout=2s CMD ["wget", "-q", "-O", "-", "http://localhost:80/"]
CMD ["/boot.sh"]
