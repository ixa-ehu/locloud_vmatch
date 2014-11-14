#!/bin/bash

bindir=/home/lcuser/vmatch/sync
dfile=/home/lcuser/vmatch/dict.txt

cd ${bindir}
perl 00-create_dict_vocab.pl -n > 00dict.txt
if [ -s 00dict.txt ]
then
    mv 00dict.txt ${dfile}
fi
