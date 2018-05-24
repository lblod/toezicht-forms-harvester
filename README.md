# Toezicht Forms Harvester

This script generates form data frontent-loket/toezicht component.

Google spreadsheet is used as data source. Please read this [tutorial](https://developers.google.com/sheets/api/quickstart/ruby) to get started.

## Expected input

<dl>
<dt>./google_api_credentials</dt>
<dd>contains the api credentials to access the data dumps. We provide you with a key</dd>
</dl>

## Expected output
<dl>
<dt>output/touzicht-forms.ttl</dt>
<dd>File with forms in a .ttl file.</dd>
</dl>

## Running the harvester
The script can be executed in a Docker container through the following command:
```bash
docker run -it --rm -v "$PWD":/app -w /app ruby:2.5 ./run.sh
```

## Developing the script
Start a Docker container:
```bash
docker run -it --name toezicht-forms-harvester -v "$PWD":/app -w /app ruby:2.5 /bin/bash
```

Execute the following commands in the Docker container:
```bash
bundle install
ruby app.rb
```
