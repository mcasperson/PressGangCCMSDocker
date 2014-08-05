# docker build -t pressgangbasetest .
# mkdir /tmp/database
# mkdir /tmp/databaselogs
# mkdir /tmp/aslogs
# sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw --name PressGang PressGangBaseTest
# docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw -i -t --name PressGang PressGangBaseTest /bin/bash
 
FROM fedora:20
 
# Expose the MariaDB, WildFly and Supervisord ports
EXPOSE 3306 8080 9990 9001
 
# Configure external volumes for the database files and application server logs
VOLUME ["/var/database", "/var/databaselogs", "/var/aslogs"]
 
# Run supervisor, which in turn will run all the other services
CMD ["/usr/bin/supervisord"]
 
# Install various apps
RUN yum install mariadb-server nano supervisor wget unzip java-1.8.0-openjdk-headless wildfly -y

# Create the user pressgang
RUN adduser pressgang
 
# Create a script to initialize the database directory if it is empty. initialdb.sql contains a clean initial database that
# will be imported into the database if there is no existing content.
ADD initial_db_setup /home/pressgang/initial_db_setup
ADD initialdb.sql /home/pressgang/initialdb.sql
RUN chmod +x /home/pressgang/initial_db_setup
 
# Add some scripts to launch applications when some condition is met. This is used because supervisord doesn't have the
# ability to add dependencies between services, and we need to have the database initialized, MariaDB started, and then
# EAP started in that order. These scripts allow us to do that.
ADD start_delay /home/pressgang/start_delay
RUN chmod +x /home/pressgang/start_delay
ADD start_wait_for_file /home/pressgang/start_wait_for_file
RUN chmod +x /home/pressgang/start_wait_for_file
ADD start_wait_for_mariadb /home/pressgang/start_wait_for_mariadb
RUN chmod +x /home/pressgang/start_wait_for_mariadb
 
# Configure supervisord. supervisord.conf comes preconfigured with all the services used by this image. 
ADD supervisord.conf /etc/supervisor/conf.d/supervisord.conf
RUN sed -i "s#%SUPERVISORD_PASS%#supervisor#" /etc/supervisor/conf.d/supervisord.conf
 
# Configure MariaDB to use the external database volume
RUN sed -i "s#datadir[[:space:]]*=[[:space:]]*/var/lib/mysql#datadir=/var/database#g" /etc/my.cnf
RUN sed -i "s#/var/log#/var/databaselogs#g" /etc/mysql/my.cnf
RUN sed -i "s#bind-address[[:space:]]*=[[:space:]]*127.0.0.1#bind-address=0.0.0.0#" /etc/my.cnf
RUN sed -i "s#\\[mysqld\\]#\\[mysqld\\]\\nbinlog_format=row#" /etc/my.cnf

# Configure PressGang
ADD wildfly/standalone/configuration/pressgang/application.properties /var/lib/wildfly/standalone/configuration/pressgang/application.properties
ADD wildfly/standalone/configuration/pressgang/entities.properties /var/lib/wildfly/standalone/configuration/pressgang/entities.properties
ADD wildfly/standalone/deployments/mysql-connector-java.jar /var/lib/wildfly/standalone/deployments/mysql-connector-java.jar
ADD wildfly/standalone/deployments/pressgang-ccms-1.9-SNAPSHOT.ear /var/lib/wildfly/standalone/deployments/pressgang-ccms-1.9-SNAPSHOT.ear
ADD wildfly/standalone/deployments/pressgang-ds.xml /var/lib/wildfly/standalone/deployments/pressgang-ds.xml
ADD wildfly/standalone/deployments/teiid-jdbc.jar /var/lib/wildfly/standalone/deployments/teiid-jdbc.jar
ADD JPPF /home/pressgang
ADD setup.cli /home/pressgang

# Fix up the database password
RUN sed -i "s#<user-name></user-name>#<user-name>admin</user-name>#" /var/lib/wildfly/standalone/deployments/pressgang-ds.xml
RUN sed -i "s#<password></password>#<password>mariadb</password>#" /var/lib/wildfly/standalone/deployments/pressgang-ds.xml