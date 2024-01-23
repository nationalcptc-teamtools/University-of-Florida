
#!/bin/sh

curl -L https://ghst.ly/getbhce > docker-compose.yml
sed -i 's/127.0.0.1/0.0.0.0/g' docker-compose.yml
docker-compose up -d

psql_id=$(docker ps -aqf "name=app-db")

#admin_id=$(docker exec -it $psql_id psql -qtAX -d bloodhound -U bloodhound -c "select id from users where principal_name='admin';")


# set the admin password to admin bc i can't figure out how to get the password from the logs
docker exec -it $psql_id psql bloodhound bloodhound -c \
"update auth_secrets set digest='\$argon2id\$v=19\$m=1048576,t=1,p=2\$QUB3+B/dvvpbOYKT9Wr1EA==\$3sV71u+fW4kX+euamzIgOQ==';"


