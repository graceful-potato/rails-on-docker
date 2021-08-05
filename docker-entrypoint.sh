#!/bin/sh
set -e

HOST_USER_ID=$(stat -c "%u" $APP_PATH)
HOST_GROUP_ID=$(stat -c "%g" $APP_PATH)
CURR_USER_ID=$(id -u $APP_USER)
CURR_GROUP_ID=$(id -g $APP_USER)

if [ $CURR_GROUP_ID != $HOST_GROUP_ID ] || [ $CURR_USER_ID != $HOST_USER_ID ]; then
  exec sudo -E env "PATH=$PATH" gosu root /bin/bash -c "
    if [ $CURR_GROUP_ID != $HOST_GROUP_ID ]; then
      groupmod -g $HOST_GROUP_ID $APP_GROUP;
    fi

    if [ $CURR_USER_ID != $HOST_USER_ID ]; then
      usermod -u $HOST_USER_ID $APP_USER;
    fi

    chown -R $APP_USER:$APP_GROUP $GEM_HOME;
    chown -R $APP_USER:$APP_GROUP /home/$APP_USER;
    chown -R $APP_USER:$APP_GROUP $APP_PATH;

    exec sudo -E env "PATH=$PATH" gosu $APP_USER /bin/bash -c \"
      if [ -f tmp/pids/server.pid ]; then
        rm tmp/pids/server.pid;
      fi

      exec $*
    \";
  ";
fi

exec "$@"

# maybe i should use 
# sudo find /home/$APP_USER -group $CURR_GROUP_ID -exec chgrp -h $APP_GROUP {} \; 2> /dev/null;
# sudo find /home/$APP_USER -user $CURR_USER_ID -exec chown -h $APP_USER {} \; 2> /dev/null;
# instead of 
# sudo chown -R $APP_USER:$APP_GROUP /home/$APP_USER;
# etc
