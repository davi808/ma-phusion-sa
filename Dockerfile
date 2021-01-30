####################################
# Ubuntu Baseimage MailArchiva Docker Image
# @todo: run this with: docker run -dt --name ma -p 22:22 -p 8090:8090 -p 8091:8091 davi807/ma-phusion-sa-v8:8.0.17
# @todo: build this with: docker build -m 4g -t davi807/ma-phusion-sa-v8:8.0.17 .
####################################

FROM phusion/baseimage:latest-amd64

# Install supporting packages for both installation and operation of MailArchiva
RUN apt-get update -y && \
    apt-get install -y openssh-server expect wget iproute2 runit fontconfig-config locales-all && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

# copy public ssl source file
COPY propertyit.pub /tmp/propertyit.pub

# install ssl and customise
RUN ln -sf /usr/share/zoneinfo/Australia/Sydney /etc/localtime && \
    cat /tmp/propertyit.pub >> ~/.ssh/authorized_keys && \
    rm -f /etc/service/sshd/down && \
    rm -f /tmp/propertyit.pub

# expose ssh port
EXPOSE 22


## --------------------------------------------------------------------
##  MAILARCHIVA INSTALLATION AND CONFIGURATION
##---------------------------------------------------------------------

# https://mailarchiva.com/downloads/

# Link to V 7.12.42 Linux Download
ENV MAILARCHIVA_BASE_URL https://mailarchiva.com/download/mailarchiva/?wpdmdl=433&ind=1609339833492

# Link to V 8.0.17 Linux Download
ENV MAILARCHIVA_BASE_URL https://mailarchiva.com/download/mailarchiva/?wpdmdl=433&ind=1611649763189

# Installation variables
ENV MAILARCHIVA_INSTALL_DIR /opt/mailarchiva
ENV MAILARCHIVA_INSTALL_TMP /tmp
ENV MAILARCHIVA_HEAP_SIZE 5192m
ENV MAILARCHIVA_DATA_PATH /var/opt/mailarchiva-data
ENV MAILARCHIVA_TAR_FOLDER /tmp/ma_dist

# copy source binaries and installation files
ADD run-mailarchiva.sh /etc/service/mailarchiva/run
# ADD mailarchiva_server_linux_v8.0.17.tar.gz $MAILARCHIVA_INSTALL_TMP
ADD expect-install $MAILARCHIVA_INSTALL_TMP/expect-install

# Get the Mailarchiva package, extract and install
RUN wget -q -O - $MAILARCHIVA_BASE_URL | tar xzf - -C $MAILARCHIVA_INSTALL_TMP &&  \
    mv $MAILARCHIVA_INSTALL_TMP/mailarchiva* $MAILARCHIVA_TAR_FOLDER && \
    mv $MAILARCHIVA_INSTALL_TMP/expect-install $MAILARCHIVA_TAR_FOLDER && \
    cd $MAILARCHIVA_TAR_FOLDER && \
    expect expect-install && \
    apt-get remove -yf expect wget && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*  && \
    mkdir -m 777 /tmp/wal 

# update java options to redirect WAL
RUN cp ${MAILARCHIVA_INSTALL_DIR}/server/startserver ${MAILARCHIVA_INSTALL_DIR}/server/startserver.old && \
    opt_java_opts_old='export JAVA_OPTS="' && \
    opt_java_opts_new='export JAVA_OPTS="-Dstorage.wal.path=/temp/wal ' && \
    escaped_opt_java_opts_old=$(printf '%s\n' "${opt_java_opts_old}" | sed 's:[][\/.^$*]:\\&:g') && \
    escaped_opt_java_opts_new=$(printf '%s\n' "${opt_java_opts_new}" | sed 's:[][\/.^$*]:\\&:g') && \
    sed -i "s/$escaped_opt_java_opts_old/$escaped_opt_java_opts_new/" /opt/mailarchiva/server/startserver 

RUN  chmod +x ${MAILARCHIVA_INSTALL_DIR}/server/startserver && \
    # setup runit to run mailarchiva on startup
    chmod +x /etc/service/mailarchiva/run

EXPOSE 8090
EXPOSE 8091
EXPOSE 25

# application data
VOLUME [ "/var/opt/mailarchiva-data" ]

# configuration files
VOLUME [ "/etc/opt/mailarchiva" ]

# log files
VOLUME [ "/var/log/mailarchiva" ] 

# storage file
VOLUME [ "/var/opt/vol" ]

# this is based on ubuntu:rolling
CMD ["/sbin/my_init"]