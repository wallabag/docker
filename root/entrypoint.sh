#!/bin/sh

FILE_ENV_VARS="$(env | grep '__FILE=')"
for env_var in $FILE_ENV_VARS; do
    var_name="$(echo $env_var | grep -o '.*__FILE=' | sed 's/__FILE=//g')"
    file_path="$(echo $env_var | grep -o '__FILE=.*' | sed 's/__FILE=//g')"
    file_content="$(cat $file_path)"
    [[ ! $? -eq 0 ]] && exit 1 # Exit if last command failed
    new_var="$(echo $var_name=$file_content)"
    export $(echo $new_var | xargs)
done

provisioner () {
    echo "Starting provisioner..."
    if ! out=`ansible-playbook -i /etc/ansible/hosts /etc/ansible/entrypoint.yml -c local "$@"`;then
        echo $out;
    fi
    echo "Provisioner finished."
}

if [ "$1" = "wallabag" ];then
    provisioner
    exec s6-svscan /etc/s6/
fi

if [ "$1" = "import" ];then
    provisioner --skip-tags=firstrun
    cd /var/www/wallabag/
    exec su -c "bin/console wallabag:import:redis-worker --env=prod $2 -vv" -s /bin/sh nobody
fi

if [ "$1" = "migrate" ];then
    provisioner
    cd /var/www/wallabag/
    exec su -c "bin/console doctrine:migrations:migrate --env=prod --no-interaction" -s /bin/sh nobody
fi

exec "$@"
