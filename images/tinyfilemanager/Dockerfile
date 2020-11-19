# Copyright 2020 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

FROM php:7

# Install dependencies
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip && \
    rm -rf /var/lib/apt/lists/*

# Install php-zip
RUN docker-php-ext-install zip

# Create user to run as, should be same UID as mounted files
RUN adduser --gecos '' --disabled-password --shell /bin/bash tfm --uid 1000

# Matches the non url prefixed version of the deployed code-server URI
WORKDIR /var/www/html/tfm

# releases at: https://github.com/prasathmani/tinyfilemanager/releases
ARG TFM_VERSION=2.4.3

# Install tinyfilemanager
RUN curl -o index.php -sfL https://raw.githubusercontent.com/prasathmani/tinyfilemanager/${TFM_VERSION}/tinyfilemanager.php

# Patch to force HTTPS
RUN sed -i 's/^$is_https =/$is_https = true ||/g' index.php

# Copy php.ini to increase allowed upload size
COPY php.ini /etc/php.ini

USER tfm

ENTRYPOINT ["/usr/local/bin/php", "-S", "0.0.0.0:3181", "-c", "/etc/php.ini", "-t", "/var/www/html/tfm"]