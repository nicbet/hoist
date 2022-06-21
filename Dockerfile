FROM ruby:2.5.3-alpine3.8

WORKDIR /app

RUN apk add git

RUN gem install bundler 

COPY . /app

RUN bundle install \
 && rake install

CMD ["hoist", "--help"]
