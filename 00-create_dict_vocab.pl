#!/usr/bin/perl

use strict;
use LWP;
use HTTP::Cookies;
use Getopt::Std;
use XML::LibXML;

binmode STDOUT, ":utf8";

my %opts;

getopts('l:', \%opts);

my $opt_lang = $opts{'l'};
$opt_lang = "en" unless defined $opt_lang;

my $skos_doc = "vocab.skos.xml";
my $xmlstring = &retrieve_skos_vocab();
die "Empty doc\n" unless defined $xmlstring;

my $tree = XML::LibXML->new->parse_string($xmlstring);

#my $tree = XML::LibXML->new->parse_file($skos_doc);

my $rdf_elem = $tree->getDocumentElement;

foreach my $skosConceptScheme_elem ($rdf_elem->getElementsByTagName("skos:ConceptScheme")) {
  my ($title_elem) = $skosConceptScheme_elem->getElementsByTagName("dc:title");
  print $title_elem->textContent."\n";
}

my %D;

foreach my $skosConcept_elem ($rdf_elem->getElementsByTagName("skos:Concept")) {
  my $about = $skosConcept_elem->getAttribute("rdf:about");
  foreach my $prefLabel ($skosConcept_elem->getElementsByTagName("skos:prefLabel")) {
    # SKOS 5.4 "A resource has no more than one value of skos:prefLabel per language tag."
    my $lang = $prefLabel->getAttribute("xml:lang");
    next unless $lang eq $opt_lang;
    $D{$prefLabel->textContent}->{$about} = 1;
  }

  foreach my $xmatch_elem ($skosConcept_elem->getElementsByTagName("skos:exactMatch")) {
    foreach my $prefLabel ($xmatch_elem->getElementsByTagName("skos:prefLabel")) {
      my $lang = $prefLabel->getAttribute("xml:lang");
      next unless $lang eq $opt_lang;
      $D{$prefLabel->textContent}->{$about} = 1;
    }
  }
}

while (my ($hw, $v) = each %D) {
  print "$hw\t".join("\t", keys %{ $v } )."\n";
}

sub get_cookies {
  my ($browser) = @_;
  my $cookie_file = "temtres_session_cookies.txt";

  my $login_url = "http://test113.ait.co.at/tematres/vocab/login.php";
  my $login_post = [id_correo_electronico => 'a.soroa@ehu.es',
		    id_password => 'a.s2014',
		    task=> 'login'
		    ];
  # configure LWP so it accepts cookies (to keep the session)
  unlink($cookie_file);
  my $cookies = HTTP::Cookies->new(
				   file => $cookie_file, autosave => 1, ignore_discard => 1);
  $browser->cookie_jar($cookies);
  my $req = $browser->post($login_url, $login_post);
  #die "Can't get cookie" unless $req->is_success;
}

sub retrieve_skos_vocab {

  my $browser = LWP::UserAgent->new(agent => "bbbbbbbb");
  &get_cookies($browser);
  my $vocab_url = "http://test113.ait.co.at/tematres/vocab/xml.php?dis=rfile&hasTopTermSKOS=&hasTopTerm=&boton=save";
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
