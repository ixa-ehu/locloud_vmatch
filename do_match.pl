#!/usr/bin/perl -w

use strict;
use FindBin qw($Bin);
use lib $Bin;
use Match;

binmode(STDIN, ":utf8");
binmode(STDOUT, ":utf8");

my ($dictionaryfile, $lang) = @ARGV;
my $input_text = <STDIN>;

my $dictionary = &load_dictionary($dictionaryfile);
my $vocab = new Match($dictionaryfile);

# sarrera:
# dc:subject@@@testua@@@dc:title@@@testua@@@
#
# output_string
#
# field@@@number@@@match_text_itzultzen_duena@@@@field@@@number@@@match_text_itzultzen_duena@@@@

my $output_str;
my $field_n = 0;

if ($input_text !~ /\@\@\@/) {
	$output_str = 'NOFIELD@@@0@@@'.&match_text($input_text, $vocab, $dictionary).'@@@@';
} else {
	my @ftext_pairs = split(/\@\@\@/, $input_text);
	while(@ftext_pairs) {
		my $field = shift @ftext_pairs;
		my $text = shift @ftext_pairs;
		last unless defined $field;
		last unless defined $text;
		$field_n++;
		next unless $text;
		next unless $field;
		my $str = &match_text($text, $vocab, $dictionary);
		$output_str .= $field.'@@@'.$field_n.'@@@'.$str.'@@@@';
	}
}

print $output_str;


# matchURI_1@@dict_1:::matchURI_2@@dict_2::: ... matchURI_N@@dict_N:::
sub match_text {

	my ($input_text, $vocab, $dictionary) = @_;

	my @tokens = split(/\s+/, lc($input_text));
	my $result = "";
	foreach my $idx ($vocab->match_idx(\@tokens)) {
		my ($left, $right) = @{ $idx };
		next if ($left == $right); # malformed entity, ignore
		my $c = join("_", @tokens[$left .. $right-1]);
		my $dict_c = $dictionary->{$c};
		next unless defined $dict_c;
		my $dict_c_lang = $dict_c->{$lang};
		next unless defined $dict_c_lang;
		my $str = "";
		foreach my $match_dict (keys %{ $dict_c_lang } ) {
			my $sep = '@@'.$match_dict.":::";
			$str = join($sep, @{ $dict_c_lang->{$match_dict} });
			$str.= $sep;
		
			$result .= $str;
		}
	}

	return $result; # field@@@number@@@matchURI_1@@dict_1:::matchURI_2@@dict_2::: ... matchURI_N@@dict_N:::
}


sub load_dictionary {

	my $fname = shift;
	my $dictionary = {};
	open(my $fh, "<:encoding(UTF-8)", "$fname") or die "Can't open $fname: $!\n";
	while (<$fh>) {
		# headword TAB lang@@concept1@@concept2@@...@@conceptN@@vocabulary_name TAB ...
		chomp;
		my($hw,@matches) = split(/\t/);
		my $dicthw = $dictionary->{$hw};
		if (!defined $dicthw) {
			$dicthw = {};
			$dictionary->{$hw} = $dicthw;
		}
		foreach my $match (@matches) {
			my ($lang, @concepts) = split(/@@/, $match);
			my $match_dict = pop @concepts;
			$dicthw->{$lang}->{$match_dict} = [@concepts];
		}
	}
	return $dictionary;
}
