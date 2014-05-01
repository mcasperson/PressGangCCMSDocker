# docker build -t PressGangBaseTest .
# mkdir /tmp/database
# mkdir /tmp/databaselogs
# mkdir /tmp/aslogs
# sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw --name PressGang PressGangBaseTest
# docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw -i -t --name PressGang PressGangBaseTest /bin/bash
 
FROM ubuntu:14.04
 
# Expose the MariaDB, WildFly and Supervisord ports
EXPOSE 3306 8080 9990 9001
 
# Configure external volumes for the database files and application server logs
VOLUME ["/var/database", "/var/databaselogs", "/var/aslogs"]
 
# Run supervisor, which in turn will run all the other services
CMD ["/usr/bin/supervisord"]

# Install MariaDB
RUN apt-get install software-properties-common -y
RUN apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db
RUN add-apt-repository 'deb http://mirror.aarnet.edu.au/pub/MariaDB/repo/10.0/ubuntu trusty main'
RUN apt-get update -y

# Answer some install questions automatically
RUN export DEBIAN_FRONTEND=noninteractive
RUN echo "mariadb-server-10.0 mysql-server/root_password password mariadb" | debconf-set-selections
RUN echo "mariadb-server-10.0 mysql-server/root_password_again password mariadb" | debconf-set-selections
 
# Install various apps
RUN apt-get install patch nano supervisor default-jre-headless unzip wget mariadb-server -y
 
# Create a script to initialize the database directory if it is empty. initialdb.sql contains a clean initial database that
# will be imported into the database if there is no existing content.
ADD initial_db_setup /root/initial_db_setup
ADD initialdb.sql /root/initialdb.sql
RUN chmod +x /root/initial_db_setup
 
# Add some scripts to launch applications when some condition is met. This is used because supervisord doesn't have the
# ability to add dependencies between services, and we need to have the database initialized, MariaDB started, and then
# EAP started in that order. These scripts allow us to do that.
ADD start_delay /root/start_delay
RUN chmod +x /root/start_delay
ADD start_wait_for_file /root/start_wait_for_file
RUN chmod +x /root/start_wait_for_file
ADD start_wait_for_mariadb /root/start_wait_for_mariadb
RUN chmod +x /root/start_wait_for_mariadb
 
# Configure supervisord. supervisord.conf comes preconfigured with all the services used by this image. 
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN sed -i "s#%SUPERVISORD_PASS%#supervisor#" /etc/supervisor/conf.d/supervisord.conf
 
# Configure MariaDB to use the external database volume
RUN sed -i "s#datadir[[:space:]]*=[[:space:]]*/var/lib/mysql#datadir=/var/database#g" /etc/mysql/my.cnf
RUN sed -i "s#/var/log#/var/databaselogs#g" /etc/mysql/my.cnf
RUN sed -i "s#bind-address[[:space:]]*=[[:space:]]*127.0.0.1#bind-address=0.0.0.0#" /etc/mysql/my.cnf
RUN sed -i "s#\\[mysqld\\]#\\[mysqld\\]\\nbinlog_format=row#" /etc/mysql/my.cnf
 
# Download EAP
ADD jboss-eap-6.2.0.zip /root/jboss-eap-6.2.0.zip
RUN unzip /root/jboss-eap-6.2.0.zip -d /root
 
# Add some modules to EAP. These are required by PressGang.
ADD mysql_module.zip /root/mysql_module.zip
RUN mkdir -p /root/jboss-eap-6.2/modules/system/layers/base/com/mysql/main
RUN unzip /root/mysql_module.zip -d /root/jboss-eap-6.2/modules/system/layers/base/com/mysql/main/
ADD teiid_module.zip /root/teiid_module.zip
RUN mkdir -p /root/jboss-eap-6.2/modules/system/layers/base/org/teiid/main
RUN unzip /root/teiid_module.zip -d /root/jboss-eap-6.2/modules/system/layers/base/org/teiid/main/
 
# Configure EAP. standalone-full.xml is a preconfigured EAP 6.2 config file.
ADD standalone-full.xml /root/jboss-eap-6.2/standalone/configuration/standalone-full.xml

# Configure PressGang
RUN mkdir -p /var/lucene/indexes
ADD application.properties /root/jboss-eap-6.2/standalone/configuration/pressgang/application.properties
ADD entities.properties /root/jboss-eap-6.2/standalone/configuration/pressgang/entities.properties
ADD pressgang-ccms-server-1.5-SNAPSHOT.war /root/jboss-eap-6.2/standalone/deployments/pressgang-ccms-server-1.5-SNAPSHOT.war
ADD pressgang-ccms-static-1.5-SNAPSHOT.war /root/jboss-eap-6.2/standalone/deployments/pressgang-ccms-static-1.5-SNAPSHOT.war
ADD pressgang-ccms-ui.war /root/jboss-eap-6.2/standalone/deployments/pressgang-ccms-ui.war