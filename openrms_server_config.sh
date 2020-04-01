#!/bin/bash



############ Configuracao Tomcat7    ########################
#Extrair os ficheiros do tomcat7 para /usr/local
tar –xzvf apache-tomcat-7.0.103.tar.gz 
mv apache-tomcat-7.0.103 /usr/local/tomcat7

# Copiar o ficheiro de configutracao do tomcat
cp setenv.sh /usr/local/tomcat7

# Copiar o ficheiro tomcat7.sh para  /etc/init.d/  ( script de inicializacao automatica do tomcat ) 
cp tomcat7.sh /etc/init.d/tomcat7

# Configurar o server para inicializar tomcat7 durante o boot
update-rc.d tomcat7 defaults

############ Configuracao OpenMRS    ########################

# Criar o directorio  /root/.OpenMRS
mkdir /root/.OpenMRS
cd .OpenMRS
cp -r *  /root/.OpenMRS/
cd ..

##########  Instalacao e configuracao  MySQL server
export MYSQL_PWD="password"
echo "mysql-server mysql-server/root_password password $MYSQL_PWD" | debconf-set-selections
echo "mysql-server mysql-server/root_password_again password $MYSQL_PWD" | debconf-set-selection

sudo add-apt-repository 'deb http://archive.ubuntu.com/ubuntu trusty universe'
sudo apt-get update
sudo apt install -y  mysql-server-5.6 mysql-client-5.6

mv /etc/mysql/my.cnf.fallback  /etc/mysql/my.cnf
cp my.cnf  /etc/mysql/my.cnf

# Configurar o MySQL Server  para inicializar  durante o boot
update-rc.d mysql defaults

### configurar backups localmente

cp databasedump.sh   /root/
#write out current crontab
crontab -l > mycron
#echo new cron into cron file
echo "  30 10  *  *   *     /root/databasedump.sh" >> mycron
#install new cron file
crontab mycron
rm mycron