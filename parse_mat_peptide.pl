#!/usr/bin/perl -w


use strict;
use DBI;
use Cwd;
use Cwd 'chdir';
use Getopt::Std;
use Data::Dumper;
use File::Basename;
use lib ('/usr/lib64/R/library/RSPerl/perl/x86_64-linux-thread-multi');

use vars
  qw($opt_i $opt_s $opt_u $opt_m $opt_p $opt_f $opt_h $opt_d $opt_o $opt_v $opt_t);
getopts('i:s:u:p:f:m:o:v:t:hd');

my $usage = "
     DESCRIPTION:
        This program check protein sequence for mutation.

     REQUIRED ARGUMENTS:
        -i na_sequence_id
        -s database server (default BHBDEV)
        -u user (default brcwarehouse)
        -p password (defailt brcwarehouse)
        -m alg
        -f filename
        -t table (default bhb_staging.daily_mat_peptide)
        -v version
        -o output mode (database/filename)

     OPTIONS:
        
        -h help
        -d debug flag   
";

my $DEBUG;
if ($opt_h) { die $usage; }

if ($opt_d) { $DEBUG = 1; }

#print "output file:$opt_o\n";
my ($outputfile);
my $savetofile = 0;
if ( $opt_o ne "database" ) {
  $outputfile = $opt_o;
  $savetofile = 1;
  open( RESULT, ">$outputfile" ) or die();
}

if ($opt_d) { $DEBUG = 1; }

my ( $inputfile, $gb_accession );
if ( $opt_f ne undef ) {
  $inputfile = $opt_f;
  $opt_f =~ s/_matpept_msa.faa$//ig;
  $opt_f =~ s/_matpept_gbk.faa$//ig;
  $opt_f =~ s/_matpept.faa//ig;
  $gb_accession = basename($opt_f);
}

my $revision = '';
my $version  = '';
if ($opt_v) { $version = $opt_v; }

my $na_sequence_id = 'NULL';
if ($opt_i) { $na_sequence_id = $opt_i; }

my $alg = '';
if ($opt_m) { $alg = $opt_m; }
print "ALG:$alg:$opt_m\n";

my $server = "BHBDEV";
if ($opt_s) { $server = $opt_s; }
my $user = "bhb_staging";
if ($opt_u) { $user = $opt_u; }
my $password = "bhb_staging#2";
if ($opt_p) { $password = $opt_p; }
#my $table = "bhb_staging.daily_mat_peptide";
my $table = "bhb_staging.stg_mat_peptide";
#my $table = "bhb_staging.stg_mat_peptide_vecna";
if ($opt_t) { $table = $opt_t; }
###
### Delete the current data...
###
my $delete_query = "
delete 
from   $table
where  gb_accession = '$gb_accession'
";
my @results = &exec_sql( $dbproc, $delete_query );

open( IN, "<$inputfile" ) or die "cannot open input file\n";
my (
  $gb_gi,       $start_position, $end_position, $mat_peptide_gi,
  $aa_sequence, $prod_name,      $gene_symbol,  $cstart,
  $partial,     $src,            $db_id,        $lit_seq,
  $gb_accession_version, $mat_peptide_accession_version, $rev
);

#print "Connecting to db: $server, $user, $password\n\n";
my $dbproc = &ConnectToDb( $server, $user, $password )
  || die "can't connect to database server: $server\n";
$dbproc->{LongReadLen} = 100000000;


my $count = 0;
while (<IN>) {
  chomp;
  s/\n//g;
  if (/>/) {
    if ( $count > 0 ) {
        print RESULT join( "\t",
          $gb_accession, $na_sequence_id, $gb_gi,       $start_position,
          $end_position, $mat_peptide_gi, $aa_sequence, 'ViPR',
          $src,          $prod_name,      $gene_symbol, $cstart,
          $partial,      $db_id,          $lit_seq,     $gb_accession_version,
          $mat_peptide_accession_version, $rev )
          . "\n";
      }
      
    }
    (
      $gb_gi,     $start_position, $end_position, $mat_peptide_gi,
      $prod_name, $gene_symbol,    $cstart,       $partial,
      $src,       $db_id,          $lit_seq,      $gb_accession_version,
      $mat_peptide_accession_version, $rev
    ) = &Parse_header($_);
    $aa_sequence = "";
    $count++;
}
  


sub Parse_header {
  my $a;
  my $source;
  my @data = split( /\|/, $_ );
  my (
    $src,            $gi,        $start,       $end,
    $mat_peptide_gi, $prod_name, $gene_symbol, $cstart,
    $partial,        $db_id,     $lit_seq,     $accession_version,
    $mat_peptide_accession_version, $rev
  );
  for my $data (@data) {
    if ( $data =~ /CDS/i ) {
      my @tks = split( /:/, $data );
      $gi = $tks[1];
      if ( $tks[1] eq "" ) {
        @tks = split( /=/, $data );
        $accession_version = $tks[1];
      }
    }
    elsif ( $data =~ /Loc/i ) {
        $data =~ s/Loc=//ig;
          print "$data\t";
          if ($data =~ /complement/i) {
            $rev = '1';

          }
        #    print "$rev\t";
        # ( $start, $end ) = split( /\.\./, $data );
        # my ($digits) = $start =~ /(\d+)/g;
        # if ( $data ne $digits . ".." . $end ) {

        # my ($digits) = $start =~ /(\d+)/g;
        #   $end   =~ /\.\.(\d+)\)/g;
        #   $start = $digits;

        # $start=$digits;
            $data =~ /(\d+)\.\.(\d+)/;
            $start = $1;
            $end = $2;
            print "Start:$start:End:$end:Rev:$rev\n";
        # }
    }

 
    elsif ( $data =~ /src/i ) {
      ( $a, $src ) = split( /=/, $data );
    }
    elsif ( $data =~ /GI/i ) {
      my @tks = split( /:/, $data );
      $mat_peptide_gi = $tks[1];
    }
    elsif ( $data =~ /product/i ) {
      my @tks = split( /=/, $data );
      $prod_name = $tks[1];
      if ( $table =~ /stg_mat_peptide/i ) {
        $prod_name =~ s/\'/\'\|\|chr(39)\|\|\'/g;
      }
    }
    elsif ( $data =~ /symbol/i ) {
      my @tks = split( /=/, $data );
      $gene_symbol = $tks[1];
    }
    elsif ( $data =~ /cstart/i ) {
      my @tks = split( /=/, $data );
      $cstart = $tks[1];
    }
    elsif ( $data =~ /Partial/i ) {
      my @tks = split( /=/, $data );
      $partial = $tks[1];
    }
  }
  if ( $src eq "GBK" || $src eq "MSA,GBK" ) {
    $source = "ALG1";
  }
  else {
    $source = $alg;
  }
  if ( $end =~ m/join/ ) {
    $lit_seq = $end;
    $lit_seq =~ s/join\(//g;
    $lit_seq =~ s/\)//g;
    $db_id = 'Exon';
    my @end = split( '\.\.', $lit_seq );
    my $size = @end;
    $end = $end[ $size - 1 ];
  }

  if ( $end =~ m/complement/ ) {
    $lit_seq = $end;
    $lit_seq =~ s/complement\(//g;
    $lit_seq =~ s/\)//g;
    $db_id = 'Exon';
    my @end = split( '\.\.', $lit_seq );
    my $size = @end;
    $end = $end[ $size - 1 ];
  }

  if ( $gi eq "" ) {
    my $select_query = "
    select string50
    from   dots.nafeatureimp
    where  string14 = '$accession_version'
    order by to_number(string50) desc
    ";
#    my @results = &do_sql( $dbproc, $select_query );
    my $string50 = "";
    foreach $string50 ( @results ) {
        $gi = $string50;
        last;
    }
  }

 #        $mat_peptide_gi = "VIPR_".$source."_".$gi."_".$start."_".$end;
  $mat_peptide_gi = createMatpeptideGi(
    'accession' => $gb_accession,
    'start_pos' => $start,
    'end_pos'   => $end,
    'source'    => $source,
    'cds_gi'    => $gi,
    'cds_accession_version' => $accession_version
  );

  $mat_peptide_accession_version = $mat_peptide_gi . '.1';

  return (
    $gi,        $start,       $end,     $mat_peptide_gi,
    $prod_name, $gene_symbol, $cstart,  $partial,
    $src,       $db_id,       $lit_seq, $accession_version,
    $mat_peptide_accession_version
  );
}
sub createMatpeptideGi {
  my %parameters = @_;
  my $accession  = $parameters{'accession'};
  my $start_pos  = $parameters{'start_pos'};
  my $end_pos    = $parameters{'end_pos'};
  my $source     = $parameters{'source'};
  my $cds_gi     = $parameters{'cds_gi'};
  my $cds_accession_version = $parameters{'cds_accession_version'};
  my $cds_id;
  my $mat_peptide_gi;

  if ( $cds_gi eq "" ) {
    $cds_id = $cds_accession_version;
  }
  else {
    $cds_id = $cds_gi;
  }

  $cds_id =~ s/\./_/g;

  $mat_peptide_gi =
    "VIPR_" . $source . "_" . $cds_id . "_" . $start_pos . "_" . $end_pos;

  print "GI:$accession\n";
  return $mat_peptide_gi;
}