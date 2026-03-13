FROM ruby:3.4-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    sqlite3 \
    libsqlite3-dev \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Bundler
RUN gem install bundler

# Copy Gemfile first for layer caching
COPY Gemfile* ./

# Install gems (will be done after we create Gemfile)
# RUN bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 9292

# Default command
CMD ["bundle", "exec", "rackup", "config.ru", "-o", "0.0.0.0", "-p", "9292"]
