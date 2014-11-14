package Match ;

#
# Erabiltzeko;
#
# use Match ;
#
# script-a Match.pm dagoen direktorio berean badago, hau jarri:
#
# use FindBin qw($Bin);
# use lib $Bin;
# use Match;
#
# Object Oriented interface:
#
#  my $vocab = new Match($dictionaryfile);
#
#  @multiwords = $vocab->do_match($words)        # splits input using spaces, ouputs multiwords with _
#  @multiwords = $vocab->do_match(\@wordsArray)  # output multiwords with _
#
#  $multiwords = $vocab->do_match($words)        # returns a join with spaces
# 
# using indices one can work on the tokens at wish:
#
#   foreach my $idx ($vocab->match_idx(\@wordsArray)) {
#     my ($left, $right) = @{ $idx };
#     next if ($left == $right);       # malformed entity, ignore
#     print join("_", @wordsArray[$left .. $right-1])."\n";
#
# Traditional interface:
#
# matchinit($dictionaryfile) ;
# $multiwords = match($tokenizedlemmatizedtext) ;

use Exporter () ;
@ISA = qw(Exporter) ;
@EXPORT = qw(matchinit match) ;

use strict;
use Carp qw(croak);

my $vocab;

sub matchinit {
  $vocab = new Match($_[0]);
}

sub match {
  $vocab->match_str($_[0]);
}

sub new {

  my $that = shift;
  my $class = ref($that) || $that;

  croak "Error: must pass dictionary filename"
    unless @_;
  my $fname = $_[0];

  my $self = {
	      fname => $fname,
	      trie => {}
	     };
  bless $self, $class;

  $self->_init();
  return $self;
}


##########################################
# member functions

#
# returns matches as indices over tokens
# 
sub match_idx {

  my $self = shift;
  my $ctx = shift;

  croak "Match object not initialized!\n"
    unless $self->{trie};

  my $words = ref($ctx) ? $ctx : [split(/\s+/, $ctx)];

  my @Idx;
  for (my $i=0; $i < @$words; $i++) {
    my ($j, $str) = $self->_match($words,$i);
    if ($j >= 0) {
      # there is a match
      push @Idx, [$i, $i+$j+1];
      $i += $j ;
    } else {
      # there is no match
      ##push @A, $words->[$i];
    }
  }
  return @Idx;
}

#
# returns matches in lowercase
#
sub do_match {

  my $self = shift;
  my $ctx = shift;

  croak "Match object not initialized!\n"
    unless $self->{trie};

  my $words = ref($ctx) ? $ctx : [split(/\s+/, $ctx)];

  my @A;
  foreach my $ipair ($self->match_idx($words)) {
    my ($left, $right) = @{ $ipair };
    next if ($left == $right);
    push @A, join("_", @{$words}[$left..$right - 1]);
  }
  return wantarray ? @A : "@A";
}


#
# these two functions are kept for backwards compatibility
# 

sub match_str {
  my $self = shift;
  return $self->do_match($_[0]);
}

sub match_arr {
  my $self = shift;
  return $self->do_match($_[0]);
}

# build structure trie-style
# $trie{'Abomination'} =>
# 0  HASH(0x83f5af8)
#    1 => ARRAY(0x83f5b40)   length 1
#       0  ''                     'Abomination'
#    2 => ARRAY(0x83f5ba0)   length 2
#       0  '(Bible)'              'Abomination (Bible)'
#       1  '(Dune)'               'Abomination (Dune)'
#       2  '(comics)'             'Abomination (comics)'
#       3  '(disambiguation)'     'Abomination (disambiguation)'
#    3 => ARRAY(0x83f5bf4)   length 3
#       0  'of Desolation'     'Abomination of Desolation'
#    4 => ARRAY(0x83f5c54)   length 4
#       0  'that Makes Desolate'     'Abomination that Makes Desolate'
#       1  'that causes Desolation'  'Abomination that causes Desolation'

sub _match {

  my $self = shift;
  my($words,$i, $trie) = @_ ;
  my ($string,$k,$length) ;

  my $wkey = lc($words->[$i]);

  return -1 if ! defined $self->{trie}->{$wkey} ;

  foreach $length (reverse sort keys %{  $self->{trie}->{$wkey} }) {
    next if ($i+$length) > $#{ $words } ;
    my $context = lc(join(" ",  @{$words}[$i+1..$i+$length])) ;
    foreach my $entry (@{ $self->{trie}->{$wkey}{$length} }) {
      return $length if $context eq $entry ;
    }
  }
  return -1 ;
}

sub _init {

  my ($self) = @_;

  my $fname = $self->{fname};

  my $fh;
  if ($fname =~ /\.bz2$/) {
    open($fh, "-|:encoding(UTF-8)", "bzcat $fname");
  } else {
    open($fh, "<:encoding(UTF-8)", "$fname");
  }
  while (<$fh>) {
    my ($entry) = split(/\t/,$_);
    my ($firstword, @rwords) = split(/_+/,$entry) ;
    my $length = @rwords ;
    next unless $firstword;
    push @{ $self->{trie}->{$firstword}->{$length} },
      join(" ", @rwords);
  }
}

sub remove_freq {

  my @res;
  foreach my $str (@_) {
    my @aux = split(/:/, $str);
    if (@aux > 1 && $aux[-1] =~ /\d+/) {
      pop @aux;
    }
    push @res, join(":", @aux);
  }
  return @res;
}

(1) ;
