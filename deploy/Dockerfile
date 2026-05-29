# Single production image: nginx (static SPA) + Rage API in one container.
# Build context = repo root.

# 1. Build the frontend
FROM node:26-slim AS web
RUN npm install -g npm@latest
WORKDIR /web
COPY web/package.json web/package-lock.json* ./
RUN npm ci
COPY web/ ./
RUN npm run build

# 2. Install gems (with build tools)
FROM ruby:3.4-slim AS gems
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      build-essential libsqlite3-dev libyaml-dev git && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY api/Gemfile api/Gemfile.lock ./
RUN gem install bundler && \
    bundle config set --local without 'development test' && \
    bundle install --jobs 4 --retry 3

# 3. Runtime: ruby-slim + nginx
FROM ruby:3.4-slim
RUN apt-get update -qq && apt-get install -y --no-install-recommends \
      nginx libsqlite3-0 libyaml-0-2 tzdata && \
    rm -rf /var/lib/apt/lists/* /etc/nginx/sites-enabled/default
WORKDIR /app
ENV RAGE_ENV=production BUNDLE_WITHOUT="development:test"
COPY --from=gems /usr/local/bundle /usr/local/bundle
COPY api/ /app/
COPY --from=web /web/dist /usr/share/nginx/html
COPY deploy/nginx.conf /etc/nginx/conf.d/default.conf
COPY deploy/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 80
CMD ["/entrypoint.sh"]
