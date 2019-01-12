#!/usr/bin/perl

use strict;
use warnings;
use lib "~/prog/lib/perl5/"; # bunsen -- 4/08/2015
use Getopt::Long;
use English;
use Carp;
use Data::Dumper;

our $VERSION = qw(1.3.1); # Jan 03, 2016
use Cwd 'abs_path'; # needed to find absolute path for input file
use File::Basename;
my $libPath = './';
BEGIN { # The modules need to exist in same dir as the script
    $libPath = (-l __FILE__) ? dirname(readlink(__FILE__)) : dirname(__FILE__);
}
use lib ("$libPath");

use Bio::SeqIO;
use Bio::Seq;
use IO::String;

##//README//##
#
# testDownloadTaxon.pl
#
# This script download and updates the taxon in Annotate_taxon_records.txt
# The family list is defined in the Annotate_Def.pm's  initRefseq subroutine.  
# Usage:  perl testDownloadTaxon.pl 2>> err.txt
# Caution: Need to verify the refseq Taxon id is up to date in Annotate_Def.pm before running this
#
#################

use Annotate_Download;
use Annotate_misc;

my $debug = 0;

#Annotate_Download::downloadTaxon('Hantaviridae', './', '1');
#Annotate_Download::checkFamilyTaxon('Hantaviridae', './', 'taxon_Hantaviridae.xml');
#Annotate_Download::checkAllTaxon('./', '1', '1');
Annotate_Download::checkAllRefseq('./', '1', '1');
exit;






