locloud_vmatch
==============

Vocabulary matching service for LoCloud

This repository contains the vocabulary matching micro-service module
developed within the LoCloud project. The module consists of a
vocabulary retriever that periodically gathers vocabularies from the
vocabulary server, and the matching script that automatically matches
the input text with concepts belonging to the retrieved vocabularies.

Installation instructions
=========================

### 1. Install the REST service

Apache (or any other HTTP server) has to be installed in the machine for the
REST service to work.

Copy the following files to the `/var/www/html/rest` directory.

    do_match.pl
    Match.pm
    vmatch.php

make sure that the ownership and permissions and properly set. For instance,
they should be something like the following:

````shell
$ ls -al /var/www/html/rest/
total 28

-rwxr-xr-x  1 root   root    998 Jul  1 10:14 do_match.pl
-rwxr-xr-x  1 root   root   4479 Jul  1 09:26 Match.pm
-rwxr-xr-x  1 root 	 root   2512 Jul 28 08:07 vmatch.php
````

### 2. Create the vocabulary database

Run the `00-create_dict_vocab.pl` script to retrieve the vocabularies from
the and store the output in `/var/www/html/rest/dict.txt`

````
$ perl 00-create_dict_vocab.pl > /var/www/html/rest/dict.txt
````

You will obviously need access to the vocabulary server at the AIT
machines. Please contact them if you experience problems. You will also want
to create a cron job which periodically performs the above job. The script
`sync_vocabs.sh` maybe useful for this task.

### 3. More information

The specifics for the service are described in the Deliverable D3.3
"Metadata Enrichment Services" of the loCloud project
[http://www.locloud.eu/Media/Files/Deliverables/D3.3-Metadata-Enrichment-services]

### 4. Service usage

The API of the service is available through the support centre of the
LoCloud project at this address:

[http://support.locloud.eu/Metadata%20enrichment%20API%20technical%20documentation]

## Contact information

````shell
Arantxa Otegi
IXA NLP Group
University of the Basque Country (UPV/EHU)
E-20018 Donostia-San Sebastián
arantza.otegi@ehu.es
````

