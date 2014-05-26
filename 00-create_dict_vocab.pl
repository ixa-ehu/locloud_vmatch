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
usage: $exec -h [-l (en|es ) ] [-v vocab_file ] [-b base_url] > dict.txt
             -h help
             -l lang (en or es)
             -v vocab_file: CSV with "vocab_name, url" pair in each line
             -b base_url url of the VM default: http://test113.ait.co.at/tematres
.
  die $usg_str;
}
my %opts;

getopts('hu:v:l:', \%opts);

&usage() if $opts{'h'};

my $opt_lang = $opts{'l'};
$opt_lang = "en" unless defined $opt_lang;

my $D = {};
my $V = &default_vocabularies($opts{'v'});

foreach my $vname (keys %{ $V } ) {
  dict_vocab($D, $vname, $V->{$vname});
}

while (my ($hw, $h) = each %{ $D }) {
  my @out = ($hw);
  while (my ($vocab, $a) = each %{ $h } ) {
    push @out, join(",", keys %{ $a } ).",$vocab";
  }
  print join("\t", @out)."\n";
}


sub dict_vocab {

  my ($D, $vocab_name, $vocab_url) = @_;

  my $skos_doc = "vocab.skos.xml";
  my $xmlstring = &retrieve_skos_vocab($vocab_url);
  if (not defined $xmlstring or $xmlstring eq "") {
    warn "$vocab_name: empty vocabulary at $vocab_url\n";
    return;
  }

  my $tree = XML::LibXML->new->parse_string($xmlstring);

  #my $tree = XML::LibXML->new->parse_file($skos_doc);

  my $rdf_elem = $tree->getDocumentElement;

  # my $vocab_name = undef;
  # foreach my $skosConceptScheme_elem ($rdf_elem->getElementsByTagName("skos:ConceptScheme")) {
  #   my ($title_elem) = $skosConceptScheme_elem->getElementsByTagName("dc:title");
  #   next unless defined $title_elem;
  #   die "Many vocabularies!\n" if defined $vocab_name;
  #   $vocab_name = $title_elem->textContent;
  # }

  # unless (defined $vocab_name) {
  #   warn "No vocabulary name!\n";
  # }

  foreach my $skosConcept_elem ($rdf_elem->getElementsByTagName("skos:Concept")) {
    my $about = $skosConcept_elem->getAttribute("rdf:about");
    foreach my $prefLabel ($skosConcept_elem->getElementsByTagName("skos:prefLabel")) {
      # SKOS 5.4 "A resource has no more than one value of skos:prefLabel per language tag."
      my $lang = $prefLabel->getAttribute("xml:lang");
      next unless $lang eq $opt_lang;
      my $hw = lc($prefLabel->textContent);
      $hw =~ s/ +/_/go;
      $D->{$hw}->{$vocab_name}->{$about} = 1;
    }

    foreach my $xmatch_elem ($skosConcept_elem->getElementsByTagName("skos:exactMatch")) {
      foreach my $prefLabel ($xmatch_elem->getElementsByTagName("skos:prefLabel")) {
	my $lang = $prefLabel->getAttribute("xml:lang");
	next unless $lang eq $opt_lang;
	my $hw = lc($prefLabel->textContent);
	$hw =~ s/ +/_/go;
	$D->{$hw}->{$vocab_name}->{$about} = 1;
      }
    }
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

sub default_vocabularies {

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
    @A = split(/\n/, &table_str());
  }
  foreach my $l (@A) {
    my ($name, $str) = split(/\,/, $l);
    #http://test113.ait.co.at/tematres/adl/index.php => http://test113.ait.co.at/tematres/adl
    $str =~ s/\/index\.php$//;
    $V->{$name} = $str;
  }
  return $V;
}

sub table_str {

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
