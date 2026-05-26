FROM ruby:3.3-slim
RUN apt-get update -qq && apt-get install -y build-essential libsqlite3-dev libyaml-dev git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY Gemfile Gemfile.lock* ./
RUN gem install bundler && bundle install
COPY . .
EXPOSE 3000
CMD ["bundle", "exec", "rage", "s", "-b", "0.0.0.0"]
