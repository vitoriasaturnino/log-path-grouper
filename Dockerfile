FROM ruby:3.1.2

RUN apt-get update -qq \
    && apt-get install -y \
    nodejs \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /log-path-grouper

COPY Gemfile /log-path-grouper/Gemfile
COPY app.rb /log-path-grouper/app.rb

RUN gem install bundler && bundle install

CMD ["ruby", "app.rb"]
