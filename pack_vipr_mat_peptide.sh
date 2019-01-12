#!/bin/sh

if [ -z "${1}" ]; # need a target
  then echo "No target is provided, please call this script as: ./pack_vipr_genotype.sh <target>";
  exit 1;

elif [ "${1}" != "${PWD##*/}" ]; # the target needs to be same as pwd
  then echo "The target has to be identical to current dir. Command: ./pack_vipr_genotype.sh <target>";
  exit 1;

else # step out of pwd, pack-up pwd, then return to pwd
  cd ..;

  # can't start with tar.gz, since that prevents more files to be added later.
#  tar -czf ${1}.tar.gz ${1}/vipr_mat_peptide.pl ${1}/vipr_mat_peptide_test.pl ${1}/vipr_mat_peptide_dev.pl ${1}/*.pm ${1}/Annotate_taxon_records.txt ${1}/Annotate_symbol_records.txt ${1}/vbrc_retrieveGBK_mysql.cfg ${1}/vipr_mat_peptide_readme.txt ${1}/GBKUpdate/*.pm ${1}/refseq/*.gb ${1}/refseq/*_extraCDS.afa ${1}/test/*.gb ${1}/test/output/*.faa ${1}/test/output/usage.out ${1}/out.txt ${1}/err.txt ${1}/out1.txt ${1}/err1.txt
  tar -cf ${1}.tar ${1}/vipr_mat_peptide.pl  ${1}/vipr_mat_peptide_parallel.pl
  tar -rf ${1}.tar ${1}/vipr_mat_peptide_test.pl  ${1}/vipr_mat_peptide_testp.pl  ${1}/vipr_mat_peptide_dev.pl
  tar -rf ${1}.tar ${1}/*.pm  ${1}/GBKUpdate/*.pm
  tar -rf ${1}.tar ${1}/refseq/*.gb  ${1}/refseq/*_extraCDS.afa
  tar -rf ${1}.tar ${1}/Annotate_taxon_records.txt  ${1}/Annotate_symbol_records.txt  ${1}/vbrc_retrieveGBK_mysql.cfg  ${1}/vipr_mat_peptide_readme.txt
  tar -rf ${1}.tar ${1}/test/*.gb  ${1}/test/output/*.faa  ${1}/test/output/usage.out
  tar -rf ${1}.tar ${1}/out.txt  ${1}/err.txt
  tar -rf ${1}.tar ${1}/pack_vipr_mat_peptide.sh

  # zip the tar file
  if [ -e ${1}.tar.gz ]
  then
    echo "File=${1}.tar.gz exists, deleted."
    rm ${1}.tar.gz
  fi
  gzip ${1}.tar

  mv ${1}.tar.gz  ${1};
  cd ${1};
  ls -l ${1}.tar.gz;

  exit 0;
fi



