#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);
use lib $Bin;
use Match;

binmode(STDIN, "utf8");
binmode(STDOUT, ":utf8");

my ($dictionaryfile, $lang, $input_text) = @ARGV;

my %dictionary;
my $fh;
open($fh, "<:encoding(UTF-8)", "$dictionaryfile");
while(<$fh>){
	# headword TAB lang@@concept1@@concept2@@...@@conceptN@@vocabulary_name TAB ...
    chomp;
    my($hw,@matches) = split(/\t/);
	my $dicthw = $dictionary{$hw};
	if(!defined $dicthw) {
		$dicthw = {};
		$dictionary{$hw} = $dicthw;
	}
	foreach my $match (@matches) {
		my ($lang, @concepts) = split(/@@/, $match);
		my $match_dict = pop @concepts;
		$dicthw->{$lang}->{$match_dict} = [@concepts];
	}
}



my $vocab = new Match($dictionaryfile);

my $result = "";

my @tokens = split(/\s+/, lc($input_text));
foreach my $idx ($vocab->match_idx(\@tokens)) {
    my ($left, $right) = @{ $idx };
    next if ($left == $right);       # malformed entity, ignore
    my $c = join("_", @tokens[$left .. $right-1]);
	my $dict_c = $dictionary{$c};
	next unless defined $dict_c;
	my $dict_c_lang = $dict_c->{$lang};
	next unless defined $dict_c_lang;
	my $str = "";
	foreach my $match_dict (keys %{ $dict_c_lang } ) {
		my $sep = '@@'.$match_dict.":::";
		$str = join($sep, @{ $dict_c_lang->{$match_dict} });
		$str.= $sep;
	}
	$result .= $str;
}

print $result; # matchURI_1@@dict_1:::matchURI_2@@dict_2::: ... matchURI_N@@dict_N:::


