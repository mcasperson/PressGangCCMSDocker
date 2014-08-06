# sudo docker build -t mcasperson/pressgangccms:v1 .
# mkdir /tmp/database; mkdir /tmp/databaselogs; mkdir /tmp/aslogs; mkdir /tmp/www
# sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -p 80:80 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw -v /tmp/www:/var/www/html:rw mcasperson/pressgangccms:v1
# sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -p 80:80 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw -v /tmp/www:/var/www/html:rw -i -t mcasperson/pressgangccms:v1 /bin/bash
 
FROM fedora:20

MAINTAINER Matthew Casperson <matthewcasperson@gmail.com>
 
# Expose the MariaDB, WildFly and Supervisord ports
EXPOSE 3306 8080 9990 9001 80
 
# Configure external volumes for the database files and application server logs
VOLUME ["/var/database", "/var/databaselogs", "/var/aslogs", "/var/www/html"]
 
# Run supervisor, which in turn will run all the other services
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
 
# Install various apps
RUN yum install mariadb-server nano supervisor wget unzip java-1.8.0-openjdk-headless xmlstarlet nodejs publican* httpd -y

# Download and extract WildFly
RUN wget -O /root/wildfly-8.1.0.Final.zip http://download.jboss.org/wildfly/8.1.0.Final/wildfly-8.1.0.Final.zip
RUN unzip /root/wildfly-8.1.0.Final.zip -d /root
 
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

# Configure PressGang. All these files come from the https://github.com/mcasperson/PressGangCCMSDeployment project
ADD wildfly/standalone/configuration/pressgang/application.properties /root/wildfly-8.1.0.Final/standalone/configuration/pressgang/application.properties
ADD wildfly/standalone/configuration/pressgang/entities.properties /root/wildfly-8.1.0.Final/standalone/configuration/pressgang/entities.properties
ADD wildfly/standalone/deployments/mysql-connector-java.jar /root/wildfly-8.1.0.Final/standalone/deployments/mysql-connector-java.jar
ADD wildfly/standalone/deployments/pressgang-ccms-1.9-SNAPSHOT.ear /root/wildfly-8.1.0.Final/standalone/deployments/pressgang-ccms-1.9-SNAPSHOT.ear
ADD wildfly/standalone/deployments/pressgang-ds.xml /root/wildfly-8.1.0.Final/standalone/deployments/pressgang-ds.xml
ADD wildfly/standalone/deployments/teiid-jdbc.jar /root/wildfly-8.1.0.Final/standalone/deployments/teiid-jdbc.jar
ADD JPPF /root/JPPF
ADD setup.cli /root/setup.cli

# Fix up the database password. These details need to match those defined in the initial_db_setup file
RUN xmlstarlet ed --inplace -u "/datasources/datasource[1]/security/user-name" -v admin /root/wildfly-8.1.0.Final/standalone/deployments/pressgang-ds.xml
RUN xmlstarlet ed --inplace -u "/datasources/datasource[1]/security/password" -v mariadb /root/wildfly-8.1.0.Final/standalone/deployments/pressgang-ds.xml

# Use NIO for HornetQ. This is required because some host OSs (like Ubuntu) don't support AIO out of the box
RUN xmlstarlet ed --inplace -N server="urn:jboss:domain:2.1" -N messaging="urn:jboss:domain:messaging:2.0"  -a "/server:server/server:profile/messaging:subsystem/messaging:hornetq-server/messaging:journal-file-size" -t elem -n "journal-type" -v "NIO" /root/wildfly-8.1.0.Final/standalone/configuration/standalone-full.xml

# Add csprocessor. The csprocessor.jar file comes from https://github.com/pressgang-ccms/PressGangCCMSCSPClient project
ADD csprocessor /usr/bin/csprocessor
RUN chmod +x /usr/bin/csprocessor
ADD csprocessor.jar /usr/lib/csprocessor/csprocessor.jar

# Add Docbuilder
ADD DocBuilder2 /root/DocBuilder2
ADD initial_docbuilder_setup /root/initial_docbuilder_setup
RUN chmod +x /root/initial_docbuilder_setup
RUN mkdir /root/.docbuilder