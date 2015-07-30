#!/usr/bin/perl

use strict;
use File::Basename;
use LWP;
use HTTP::Cookies;
use Getopt::Std;
use XML::LibXML;
use Encode;

binmode STDOUT, ":utf8";

sub usage {

  my $exec = basename($0);
  my $usg_str = <<".";
usage: $exec [-h] [-v vocab_file ] [-V voxab_file ] [-n] [-s] > dict.txt
             -h help
             -n be silent (supress warnings and error messages)
             -v load vocab list from CSV with "vocab_name, url" pair in each line
             -V save vocab list into vocab_file
             -s save SKOS files
.
  die $usg_str;
}

# call this URL to get a list of supported vocabularies
my $VOCAB_LIST_URL = "http://test113.ait.co.at/tematres/locloud-vocabularies/";

my %opts;

getopts('nshV:v:', \%opts);

my $opt_n = $opts{'n'};

&usage() if $opts{'h'};

my $opt_s = $opts{'s'};

my $D = {};

if (@ARGV) {
  # a skos file has been selected. Use it (only)
  foreach my $fname (@ARGV) {
    my $tree = XML::LibXML->new->parse_file($fname);
    my $vocab_name = basename(decode("UTF-8", $fname), ".skos");
    dict_populate_tree($D, $vocab_name, $tree);
  }
} else {
  my $V = &vocab_list($opts{'v'});
  foreach my $vname (keys %{ $V } ) {
    dict_vocab($D, $vname, $V->{$vname});
  }
}

&print_dict($D);

# format
# headword TAB lang@@concept1@@concept2@@...@@conceptN@@vocabulary_name TAB ...

sub print_dict {

  my $D = shift;
  while (my ($hw, $h) = each %{ $D }) {
    my @out = ($hw);
    while (my ($vocab, $lh) = each %{ $h } ) {
      while(my ($lang, $a) = each %{ $lh } ) {
	next unless keys %{ $a };
	push @out, "$lang".'@@'.join('@@', keys %{ $a } ).'@@'."$vocab";
      }
    }
    print join("\t", @out)."\n";
  }
}

sub dict_vocab {

  my ($D, $vocab_name, $vocab_url) = @_;

  my $skos_doc = "vocab.skos.xml";
  my $xmlstring = &retrieve_skos_vocab($vocab_url);
  if (not defined $xmlstring or $xmlstring eq "") {
    warn "$vocab_name: empty vocabulary at $vocab_url\n" unless $opt_n;
    return;
  }
  my $tree = XML::LibXML->new->parse_string($xmlstring);

  &dict_populate_tree($D, $vocab_name, $tree);
}

sub dict_populate_tree {

  my ($D, $vocab_name, $tree) = @_;

  if (defined $opt_s) {
    open (my $fh, ">$vocab_name.skos") or die;
    binmode $fh;
    print $fh $tree->toString(2);
  }

  my $rdf_elem = $tree->getDocumentElement;

  foreach my $skosConcept_elem ($rdf_elem->getElementsByTagName("skos:Concept")) {
    my $about = $skosConcept_elem->getAttribute("locloud");
	$about = $skosConcept_elem->getAttribute("rdf:about") unless defined $about;
    &parse_labels($skosConcept_elem, $vocab_name, $about, $D);
    foreach my $xmatch_elem ($skosConcept_elem->getElementsByTagName("skos:exactMatch")) {
      my $match_about = $xmatch_elem->getAttribute("rdf:about");
      next unless $match_about;
      &parse_labels($xmatch_elem, $vocab_name, $match_about, $D);
    }
  }
}

sub parse_labels {
  my ($concept_elem, $vocab_name, $about, $D) = @_;

  foreach my $label_elem ($concept_elem->getElementsByTagName("*")) {
    next unless $label_elem->nodeName =~ /Label/;
    # SKOS 5.4 "A resource has no more than one value of skos:prefLabel per language tag."
    my $lang = $label_elem->getAttribute("xml:lang");
    next unless $lang;
    my $hw = lc($label_elem->textContent);
    next unless $hw;
    $hw =~ s/ +/_/go;
    $D->{$hw}->{$vocab_name}->{$lang}->{$about} = 1;
  }
}

sub get_cookies {
  my ($browser, $login_url) = @_;
  my $cookie_file = "temtres_session_cookies.txt";

  my $login_post = [id_correo_electronico => 'a.soroa@ehu.es',
		    id_password => 'a.s2014',
		    task=> 'login'
		    ];
  # configure LWP so it accepts cookies (to keep the session)
  unlink($cookie_file);
  my $cookies = HTTP::Cookies->new(file => $cookie_file,
				   autosave => 1,
				   ignore_discard => 1);
  $browser->cookie_jar($cookies);
  my $req = $browser->post($login_url, $login_post);
  #die "Can't get cookie" unless $req->is_success;
}

sub retrieve_skos_vocab {

  my ($burl) = @_;

  my $browser = LWP::UserAgent->new(agent => "bbbbbbbb");
  my $cookie_url = $burl."/login.php";
  my $vocab_url = $burl."/xml.php?dis=rfile&hasTopTermSKOS=&hasTopTerm=&boton=save";

  &get_cookies($browser, $cookie_url);
  my $response = $browser->get( $vocab_url );
  return undef unless $response->is_success;
  return $response->content;
}

  # my $vocab = &do_POST( $browser,
  # 			'http://test113.ait.co.at/tematres/vocab/xml.php',
  # 			{ 'dis' => 'rfile',
  # 			  'hasTopTermSKOS' => '',
  # 			  'hasTopTerm' => '',
  # 			  'boton' => 'save'
  # 			} );

sub vocab_list {

  my ($fname) = @_;

  my @A = ();
  my $V = {};
  if (defined $fname) {
    open (my $fh, $fname) or die "Can't open $fname:$!\n";
    binmode $fh, ":utf8";
    while(<$fh>) {
      chomp;
      push @A, $_;
    }
  } else {
    @A = &retrieve_vocab_list();
  }
  foreach my $l (@A) {
    my ($name, $str) = split(/\,/, $l);
    #http://test113.ait.co.at/tematres/adl/index.php => http://test113.ait.co.at/tematres/adl
    $str =~ s/\/index\.php$//;
    $V->{$name} = $str;
  }
  return $V;
}


sub retrieve_vocab_list {

  my $browser = LWP::UserAgent->new(agent => "bbbbbbbb");

  my $response = $browser->get( $VOCAB_LIST_URL );
  if (not $response->is_success) {
    warn "[W] Error getting $VOCAB_LIST_URL\n".$response->status_line unless $opt_n;
    exit 1;
  }
  my @A;

  # Save list if told so

  if ($opts{'V'} and open(my $fhkk, ">".$opts{'V'})) {
	  binmode $fhkk,':raw';
	  print $fhkk $response->content;
  }

  # open(my $fhkk, ">kkk");
  # binmode $fhkk,':raw';
  # print $fhkk $response->content;
  # binmode $fhkk,':utf8';
  # print $fhkk decode("utf8", $response->content);
  # die;
  #my $content = decode("iso-8859-1", $response->content);
  my $content = decode("utf8", $response->content);
  unless ($content) {
    warn "[E] Can not retrieve vocabulary list\n" unless $opt_n;
    exit 1;
  }
  foreach my $line (split(/\n/, $content)) {
    $line =~ s/\r$//;
    # $line =~ s/^\"//;
    # $line =~ s/"$//;
    next unless $line;
    my ($name, $url) = parse_vocab_line($line);
    if (not defined $name or not defined $url) {
      warn "Bad line: $line\n" unless $opt_n;
      next;
    }
    $name =~ s/^\s+//;
    $name =~ s/\s+$//;
    $url =~  s/^\s+//;
    $url =~  s/\s+$//;
    push @A, "$name,$url";
  }
  push @A, 'dm:Genres,http://test113.ait.co.at/tematres/vocab/index.php';
  return @A;
}


sub parse_vocab_line {

  my $line = shift;

  return map { s/^\"//; s/\"$//; $_ } split(/\t/, $line);
}

sub parse_vocab_v0 {

  my $line = shift;
  my @vname;
  my $url = undef;

  foreach my $w (split(/\s+/, $line)) {
    if ($w =~ /^http/) {
      $url = $w;
      last;
    }
    push @vname, $w;
  }
  my $vocab = undef;
  $vocab = join(" ", @vname) if @vname;
  return ($vocab, $url);
}

sub table_str_fixed {

  my $str= <<'.';
Alexandria Digital Library Feature Type Thesaurus,http://test113.ait.co.at/tematres/adl/index.php
General Multilingual Environmental Thesaurus GEMET,http://test113.ait.co.at/tematres/Gemet/index.php
General Subject headings for Film Archives,http://test113.ait.co.at/tematres/fiaf/index.php
MDA Archaeological Objects Thesaurus,http://test113.ait.co.at/tematres/arcobjects/index.php
Relator Terms for Use in Rare Book and Special Collections Cataloguing,http://test113.ait.co.at/tematres/rbms/index.php
Tesauro de Ciencias de la Documentación,http://test113.ait.co.at/tematres/docutes/index.php
Thesaurus for Graphic Materials 1: Subject Terms,http://test113.ait.co.at/tematres/tgm1/index.php
Thesaurus for Graphic Materials 2: Genre and Physical Characteristic Terms,http://test113.ait.co.at/tematres/tgm2/index.php
Thesaurus PICO 4.1,http://test113.ait.co.at/tematres/pico/index.php
UK Archival Thesaurus (UKAT),http://test113.ait.co.at/tematres/ukat/index.php
UNESCO thesaurus,http://test113.ait.co.at/tematres/unesco/index.php
dm:Genres,http://test113.ait.co.at/tematres/vocab/index.php
.
  return decode("utf8", $str);
}
