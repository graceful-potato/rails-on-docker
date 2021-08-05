ARG RUBY_VERSION
FROM ruby:$RUBY_VERSION

ARG NODE_MAJOR
ARG BUNDLER_VERSION
ARG YARN_VERSION
ARG APP_USER
ARG APP_GROUP
ARG APP_PATH

ENV APP_USER=$APP_USER
ENV APP_GROUP=$APP_GROUP
ENV APP_PATH=$APP_PATH

# Add NodeJS to sources list
RUN curl -sL https://deb.nodesource.com/setup_$NODE_MAJOR.x | bash -

# Add Yarn to the sources list
RUN curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | apt-key add - \
  && echo "deb https://dl.yarnpkg.com/debian/ stable main" | tee /etc/apt/sources.list.d/yarn.list

RUN apt-get update -yqq && apt-get install -yqq --no-install-recommends \
  nodejs \
  yarn=$YARN_VERSION-1 \
  gosu \
  sudo \
  vim \
  postgresql-client
  # install postgresql-client if you want to be able to call rails db or psql from web container
  # but you always can access psql from database container with docker-compose exec database psql -U postgres

RUN groupadd -g 5555 $APP_GROUP && \
    useradd -m -u 5555 -g $APP_GROUP -G sudo $APP_USER && \
    echo "$APP_USER ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$APP_USER && \
    chmod 0440 /etc/sudoers.d/$APP_USER

ENV LANG=C.UTF-8 \
  BUNDLE_JOBS=4 \
  BUNDLE_RETRY=3

RUN gem update --system && \
    gem install bundler:$BUNDLER_VERSION

RUN mkdir -p $APP_PATH && \
    chown $APP_USER:$APP_GROUP $APP_PATH

WORKDIR $APP_PATH

USER $APP_USER

RUN mkdir -p $APP_PATH/node_modules

ENTRYPOINT [ "./docker-entrypoint.sh" ]
