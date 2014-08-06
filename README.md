These files can be used to create an image hosting PressGang inside Docker. It relies on the ZIP artifact created by the https://github.com/mcasperson/PressGangCCMSDeployment project, and the JAR artifact created by the https://github.com/pressgang-ccms/PressGangCCMSCSPClient project, and the application at https://github.com/mcasperson/DocBuilder2.
 
The Docker image created by this project has been uploaded to the Docker repository at https://registry.hub.docker.com/u/mcasperson/pressgangccms/. To use it, run the following commands

```bash
mkdir /tmp/database
mkdir /tmp/databaselogs
mkdir /tmp/aslogs
sudo docker run -p 8080:8080 -p 9001:9001 -p 3306:3306 -v /tmp/database:/var/database:rw -v /tmp/databaselogs:/var/databaselogs:rw -v /tmp/aslogs:/var/aslogs:rw mcasperson/pressgangccms:v1
```

Then open http://localhost:8080/pressgang-ccms-ui in your browser.