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


## Extending the forms
Some recipes...
### Basic
Changes will mostly be related to the decision types. Adding, removing a field or adding a new decision type
In file `TypeBesluit_Eigenschap_Rel-aangepast.xlsx[PROD]` you will be able to do so.
To add a field:
* add a Row
* column ID should be big enough and unique number within the sheet
* TYPEBESLUITID, is the type of decision the form relates to. It is the ID in `TypeBesluit-aangepast.xlsx[PROD]`
* EIGENSCHAPID, is the ID of the field you want to add. Located in `Eigenschap-aangepast.xlsx[PROD]`
* TYPE-MAP: copy paste from other rows.

### Advanced: Nested subforms
Recently, we needed to nest a subform based on the value of another input-field (type reglement).
Here you will have to modify `dynamic-subforms [not based on besluittype]`
To add a subform:
* add a Row
* ID == id of the subform
* ORIG_EIGENSCHAP_ID: is the ID of the field which should trigger a subform.  Located in `Eigenschap-aangepast.xlsx[PROD]`
* EIGENSCHAPWAARDE_ID: the value of the field on which the subform should appear. You should provide the ID from `Eigenschapwaarde.xlsx[PROD]`
* EIGENSCHAPID: is the ID of the field you want to add to the subform. Located in `Eigenschap-aangepast.xlsx[PROD]`
* TYPE-MAP: copy paste from other rows.


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
