#!/bin/sh

script_dir=$(dirname "$0")

. "$script_dir"/lib.sh

kind=$1

# shift if we have to
if [ "$kind" = "full" ] || [ "$kind" = "webapp" ] || [ "$kind" = "worker" ]; then
    shift
fi

echo $kind

# default to full
if [ -z "$kind" ] || ( [ "$kind" != "webapp" ] && [ "$kind" != "worker" ] ); then
    kind="full"
fi

env_file=$script_dir/.env
env_example_file=$script_dir/.env.example

if [ ! -f "$env_file" ]; then
    read -p "No .env file found, would you like to create one? [Y/n] " yn
    case $yn in
        [nN]* )
            echo "Skipping .env file creation. The next steps will likely fail."
            ;;
        * )
            cp -v "$env_example_file" "$env_file"

            read -p "Would you also like to generate fresh secrets? [Y/n] " yn
            case $yn in
                [nN]* )
                    echo "Skipping secret generation. You should really not skip this step."
                    ;;
                * )
                    if ! generate_secrets "$env_file"; then
                        echo "Failed to generate secrets. Exiting."
                        exit 1
                    fi
                    sleep 2
                    ;;
            esac
            ;;
    esac
fi

if [ "$kind" != "webapp" ]; then
    echo "Ensuring cleanup service exists and is enabled..."
    sudo cp "$script_dir/cleanup/trigger-cleanup.service" /etc/systemd/system/
    sudo cp "$script_dir/cleanup/trigger-cleanup.timer" /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable trigger-cleanup.timer --now
    echo "Done! Starting trigger"
fi;

if [ "$kind" = "full" ]; then
    compose_file=$script_dir/docker-compose.yml
    extra_args="-p=trigger"
else
    compose_file=$script_dir/docker-compose.$kind.yml
    extra_args="-p=trigger-$kind"
fi

if [[ ! "$@" == *"-d"* ]]; then
    echo "Warning: Detached mode (-d) is not enabled."
    echo -n "Would you like to continue running the script? (y/N): "
    read answer
    
    # Convert answer to lowercase for easier comparison
    answer=$(echo "$answer" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$answer" != "y" && "$answer" != "yes" ]]; then
        echo "Cancelled."
        exit 1
    fi
fi

docker_compose -f "$compose_file" "$extra_args" up "$@"
