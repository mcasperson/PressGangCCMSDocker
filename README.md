These files can be used to create an image hosting PressGang inside Docker. It relies on the ZIP artifact created by the https://github.com/mcasperson/PressGangCCMSDeployment project, and the JAR artifact created by the https://github.com/pressgang-ccms/PressGangCCMSCSPClient project, and the application at https://github.com/mcasperson/DocBuilder2.
 
The Docker image created by this project has been uploaded to the Docker repository at https://registry.hub.docker.com/u/mcasperson/pressgangccms/. To use it, run the following commands

```bash
sudo docker pull mcasperson/pressgangccms:v1
sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /opt/pressgang/database:/var/database:rw -v /opt/pressgang/databaselogs:/var/databaselogs:rw -v /opt/pressgang/aslogs:/var/aslogs:rw -v /opt/pressgang/www:/var/www/html:rw mcasperson/pressgangccms:v1
```

Then open http://localhost:8080/pressgang-ccms-ui in your browser.
