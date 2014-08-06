# docker build -t mcasperson/pressgangccms:v1 .
# mkdir /tmp/database
# mkdir /tmp/databaselogs
# mkdir /tmp/aslogs
# sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw mcasperson/pressgangccms:v1
# sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw -i -t mcasperson/pressgangccms:v1 /bin/bash
 
FROM fedora:20

MAINTAINER Matthew Casperson <matthewcasperson@gmail.com>
 
# Expose the MariaDB, WildFly and Supervisord ports
EXPOSE 3306 8080 9990 9001
 
# Configure external volumes for the database files and application server logs
VOLUME ["/var/database", "/var/databaselogs", "/var/aslogs"]
 
# Run supervisor, which in turn will run all the other services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
 
# Install various apps
RUN yum install mariadb-server nano supervisor wget unzip java-1.8.0-openjdk-headless wildfly xmlstarlet -y

# The WildFly RPM installed above misses a few symbolic links. Without these links, you'll get a lot of
# "File not found" errors when starting WildFly.
RUN ln -s /usr/share/java/jboss-marshalling/jboss-marshalling-river.jar /usr/share/java/jboss-marshalling-river.jar
RUN ln -s /usr/share/java/resteasy/resteasy-json-p-provider-jandex.jar /usr/share/wildfly/modules/system/layers/base/org/jboss/resteasy/resteasy-json-p-provider/main/resteasy-json-p-provider-jandex.jar
 
# Create a script to initialize the database directory if it is empty. initialdb.sql contains a clean initial database that
# will be imported into the database if there is no existing content.
ADD initial_db_setup /root/initial_db_setup
ADD initialdb.sql /root/initialdb.sql
RUN chmod +x /root/initial_db_setup
 
# Add some scripts to launch applications when some condition is met. This is used because supervisord doesn't have the
# ability to add dependencies between services, and we need to have the database initialized, MariaDB started, and then
# WildFly started in that order. These scripts allow us to do that.
ADD start_delay /root/start_delay
RUN chmod +x /root/start_delay
ADD start_wait_for_file /root/start_wait_for_file
RUN chmod +x /root/start_wait_for_file
ADD start_wait_for_mariadb /root/start_wait_for_mariadb
RUN chmod +x /root/start_wait_for_mariadb
 
# Configure supervisord. supervisord.conf comes preconfigured with all the services used by this image. 
ADD supervisord.conf /etc/supervisord.conf
RUN sed -i "s#%SUPERVISORD_PASS%#supervisor#" /etc/supervisord.conf
 
# Configure MariaDB to use the external database volume
RUN sed -i "s#datadir[[:space:]]*=[[:space:]]*/var/lib/mysql#datadir=/var/database#g" /etc/my.cnf
RUN sed -i "s#/var/log#/var/databaselogs#g" /etc/my.cnf
RUN sed -i "s#bind-address[[:space:]]*=[[:space:]]*127.0.0.1#bind-address=0.0.0.0#" /etc/my.cnf
RUN sed -i "0,/^\\[mysqld\\]/{s#\\[mysqld\\]#\\[mysqld\\]\\nbinlog_format=row#}" /etc/my.cnf

# Configure PressGang
ADD wildfly/standalone/configuration/pressgang/application.properties /etc/wildfly/standalone/configuration/pressgang/application.properties
ADD wildfly/standalone/configuration/pressgang/entities.properties /var/lib/wildfly/standalone/configuration/pressgang/entities.properties
ADD wildfly/standalone/deployments/mysql-connector-java.jar /var/lib/wildfly/standalone/deployments/mysql-connector-java.jar
ADD wildfly/standalone/deployments/pressgang-ccms-1.9-SNAPSHOT.ear /var/lib/wildfly/standalone/deployments/pressgang-ccms-1.9-SNAPSHOT.ear
ADD wildfly/standalone/deployments/pressgang-ds.xml /var/lib/wildfly/standalone/deployments/pressgang-ds.xml
ADD wildfly/standalone/deployments/teiid-jdbc.jar /var/lib/wildfly/standalone/deployments/teiid-jdbc.jar
ADD JPPF /root
ADD setup.cli /root/setup.cli

# Fix up the database password. These details need to match those defined in the initial_db_setup file
RUN xmlstarlet ed --inplace -u "/datasources/datasource[1]/security/user-name" -v admin /var/lib/wildfly/standalone/deployments/pressgang-ds.xml
RUN xmlstarlet ed --inplace -u "/datasources/datasource[1]/security/password" -v mariadb /var/lib/wildfly/standalone/deployments/pressgang-ds.xml