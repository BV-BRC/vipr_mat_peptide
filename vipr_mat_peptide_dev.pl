#!/usr/bin/perl

use strict;
use warnings;
use version; our $VERSION = qv('1.1.6'); # Nov 07, 2012
use File::Temp qw/ tempfile tempdir /;
use Getopt::Long;
use English;
use Carp;
use Data::Dumper;

use Bio::SeqIO;
use Bio::Seq;
use Bio::AlignIO;
#use Bio::Tools::Run::StandAloneBlast;
#use Bio::Tools::Run::Alignment::Muscle;
use IO::String;

#use lib qw(/net/home/gsun/northrop/matpeptide/vipr_mat_peptide-1.1.3/);
use GBKUpdate::Configuration;
use GBKUpdate::Database;

## Path to the CLUSTALW binaries. Change the CLUSTALW location in Annotate_Def.pm

use Annotate_Download;
use Annotate_misc;

my $debug_all  = 1; # Used to turn off all debugging code
my $debug      = 1;
my $withDB     = 1; # If the genomes are optionally stored in a MySQL database
my $test1      = 0;

##//README//##
#
# vipr_mat_peptide_dev.pl
#
# This script uses a refseq to annotate the polyprotein in a genome file
# It outputs a file named as <accession>_matpept_msa.faa with the annotated mat_peptides in fasta format
# if the result comes from alignment. Otherwise, outputs to a file <accession>_matpept_gbk.faa when the
# result comes from genbank.
#
# INPUT: dir of input file, input genome file name, ticket (used as subfolder), optional refseq file name
#
# OUTPUT: fasta file containing the annotated mat_peptide sequence
#
# DEPENDENCIES:
# This script calls perl and uses BioPerl modules.
#
# USAGE:
# For single input genome
# ./vipr_mat_peptide.pl -r [refseq] -d [dir_path] -i [inputFile.gb]
# For multiple input genomes within a directory
# ./vipr_mat_peptide.pl -d [dir_path] -l [directory]
# For multiple input genomes whose accession is in a list, and gbk files are in MySQL database
# ./vipr_mat_peptide.pl -d [dir_path] -l [list_file.txt]
# e.g.
# ./vipr_mat_peptide.pl -d ./ -i NC_001477_test.gb >> out.txt 2>> err.txt
# ./vipr_mat_peptide.pl -d ./ -l test >> test/out.txt 2>> test/err.txt
# ./vipr_mat_peptide.pl -d test -l nuccore_result.txt >> test/out.txt 2>> test/err.txt
#
#    Authors: Chris Larsen, clarsen@vecna.com; Guangyu Sun, gsun@vecna.com;
#    September 2011
#
#################

## Path to the BLAST binaries. You must configure this!
my $td = tempdir( CLEANUP => 1 );  # temp dir (threadsafe)

# Get user-defined options
my $refseq_required = 0;
my $refseq_fn = '';
my $infile    = '';
my $list_fn   = '';
my $dir_path  = './';
my $checkRefseq = 0;
#my $checkTaxon = 0;
my @aln_fn    = ();
my $aln_fn    = \@aln_fn;

my $exe_dir  = './';
my $exe_name = $0;
if ($exe_name =~ /^(.*[\/])([^\/]+[.]pl)$/i) {
    $exe_dir  = $1;
    $exe_name = $2;
}
print STDERR "$exe_name: $0 $VERSION executing from command='$0 @ARGV' ".POSIX::strftime("%m/%d/%Y %H:%M:%S", localtime)."\n";
my $useropts = GetOptions(
                 "checkrefseq"  => \ $checkRefseq,    # Check any update for RefSeqs from genbank
#                 "checktaxon"  => \ $checkTaxon,    # Check any update for taxon from genbank
                 "d=s"  => \ $dir_path,    # Path to directory
                 "i=s"  => \ $infile,      # [inputFile.gbk]
                 "l=s"  => \ $list_fn,     # directory with the gbk file, or list of accessions from genbank search
                 "r=s"  => \ $refseq_fn,   # refseq in gbk file
                 "a=s"  => \ @aln_fn,      # alignment file
                 "t=i"  => \ $test1,       # quit after one run
                 );
$dir_path =~ s/[\/]$//;
$list_fn =~ s/[\/]$//;

print STDERR "$exe_name: Directory=$dir_path \talignment file='@$aln_fn'\n";

# Either a genbank file or a folder/list of genbank files is required
if ($checkRefseq) {
#    my $count = Annotate_Def::checkAllTaxon( $exe_dir);
    print STDERR "\n$exe_name: start to check taxon.\n";
    my $count = Annotate_Download::checkAllTaxon( $exe_dir);
    printf STDERR "\n$exe_name: finished checking %d taxon, exit.\n\n", $count;

#    $count = Annotate_Def::checkAllRefseq( $exe_dir);
    print STDERR "\n$exe_name: start to check RefSeq.\n";
    $count = Annotate_Download::checkAllRefseq( $exe_dir);
    printf STDERR "\n$exe_name: finished checking %d RefSeqs, exit.\n\n", $count;
    exit(1);
#} elsif ($checkTaxon) {
#    exit(1);

} elsif (!$infile && !$list_fn) {
    print Annotate_misc::Usage( $exe_name, $exe_dir);
    exit(1);
}

if ($refseq_fn) {
    print STDERR "$exe_name: Refseq supplied in $refseq_fn.\n";
    $refseq_required = 1;
}

##################

## //EXECUTE// ##

# Get refseq object if $refseq_fn is given
  my $dbh_ref = undef;
  my $refseq;
  if ($refseq_fn) {
      print STDERR "$exe_name: refseq read from $refseq_fn\n";
      $refseq = Annotate_Def::get_refseq( $refseq_fn);
  }

# Now go through the input file of sequences
if ("$infile") {

    print STDERR "$exe_name: Input genbank file '$dir_path/$infile'\n";
    if ($infile !~ m/[.](gb|gbk|genbank)/i) {
        print STDERR "$exe_name: WARNING: please make sure input genbank file '$infile' is in genbank format\n";
    }

    # Now run the annotation
    my $accs = [];
    push @$accs, [$#{$accs}+1, "$dir_path/$infile"];

    $dbh_ref = undef;
    Annotate_misc::process_list1( $accs, $aln_fn, $dbh_ref, $exe_dir, $exe_name, $dir_path);

} elsif ("$dir_path/$list_fn") {

    print STDERR "$exe_name: Input accession are in dir/file '$dir_path/$list_fn'\n";
    my $accs = [];
    if (-d "$dir_path/$list_fn") {
        $dir_path = "$dir_path/$list_fn";
        # if input -l file is directory
        my $ptn = '^\s*([^\s]+)(\.(gb|gbk|genbank))\s*$';
        $accs = Annotate_misc::list_dir_files( "$dir_path", $ptn);
        my $n = $#{$accs}+1;
        print STDERR "$exe_name: from directory: $dir_path, found $n gbk files.\n";
        for my $j (0 .. $#{$accs}) {
            print STDERR "$exe_name: \$acc[$j]=$accs->[$j]->[1]\n";
        }
        print STDERR "\n";
#        $debug && print STDERR "$exe_name: \$accs=\n".Dumper($accs)."End of \$accs\n\n";

        $dbh_ref = undef;
    } elsif (-f "$dir_path/$list_fn") {
        croak("$exe_name: Need to turn on \$withDB to connect to MySQL database.") if (!$withDB);
        my $list_file;
        open $list_file, '<', "$dir_path/$list_fn"
           or croak("$exe_name: Found $list_fn, but couldn't open");
        while (<$list_file>) {
            my ($number, $acc);
            chomp;
#           print $_;
            if ($_ =~ /^\s*(\d+)\s*:\s*([^\s]+)\s*$/) { # '440: NC_002031'
                $number = $1;
                $acc = $2;
                print STDERR "\$1=\'$1\' \t\$2=\'$2\'\n";
            } elsif ($_ =~ /^\s*([^\s.]+)[.]\d+\s*$/) { # FJ888392.1
                $number = $#{$accs} +1;
                $acc = $1;
#                print STDERR "\$1=\'$1\'\n";
            } elsif ($_ =~ /^(\d+)[.] /) { # 1. Norovirus Hu/
                $number = $1;
#                $_ = <$list_file>;
#                $_ = <$list_file>;
#                print STDERR "\$_='$_'\n";
                while (<$list_file>) {
                  if ($_ =~ /^([a-z0-9_]+)[.]\d /i) { # FR695417.1 GI:308232890
                    $acc = $1;
                    print STDERR "$exe_name: \$number=\'$number\' \$acc=$acc\n";
                  }
                  last if ($_ =~ /^$/x)
                }
            } else {
               0 && $debug && print STDERR "$exe_name: skipping line: '$_'\n" if ($_ || $_ ne "/n");
               next;
            }
            push @$accs, [$number, $acc];

        }
        close $list_file or croak "$0: Couldn't close $dir_path/$list_fn: $OS_ERROR";

        my $n = $#{$accs}+1;
        print STDERR "$exe_name: finished reading list file: $dir_path/$list_fn, found $n gbk files.\n\n";
#        $debug && print STDERR "$exe_name: \$accs=\n".Dumper($accs)."End of \$accs\n\n";

        # configuration file used to connect to MySQL
        my $cfg_file = $exe_dir .'vbrc_retrieveGBK_mysql.cfg';
        my $config_ref = GBKUpdate::Configuration->new($cfg_file);
#        $debug && print "$0: \$config_ref=\n". Dumper($config_ref) . "\n";

        $dbh_ref = GBKUpdate::Database->new($config_ref);
#       $debug && print "$0: \$dbh_ref ='". Dumper($dbh_ref) ."'\n";

    } else {
        croak("$exe_name: Couldn't locate accession file/directory: $list_fn: $OS_ERROR");
    }

    if ( 1 ) {
        # MSA for each genome
        $debug && print STDERR "$exe_name: sub Annotate_misc::process_list1 called\n";
        Annotate_misc::process_list1( $accs, $aln_fn, $dbh_ref, $exe_dir, $exe_name, $dir_path);
    } else {
        # Giant MSA. For large set, requires long time, run out of time/memory, and possibly give wrong result b/c of gaps
        if ( !$debug ) {
            croak("$exe_name: sub Annotate_misc::process_list3 is for debug only. Quit.\n");
        }
        Annotate_misc::process_list3( $accs, $aln_fn, $dbh_ref, $exe_dir, $exe_name, $dir_path);
    }
}

    print "\n$exe_name: finished.\n\n";
    print STDERR "\n$exe_name: finished.\n\n";

exit(0);


1;
