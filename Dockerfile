FROM ruby:2.4.0
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev nodejs && apt-get install ruby-dev -y
ENV INSTALL_PATH /faye_server
RUN mkdir -p $INSTALL_PATH
WORKDIR $INSTALL_PATH
COPY Gemfile Gemfile
RUN bundle install
COPY . .
VOLUME ["$INSTALL_PATH/public"]
CMD rackup -p 9292 -o 0.0.0.0 -s puma -E production app/config.ru
