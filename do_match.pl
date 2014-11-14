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
    chomp;
    my($concept,@matches) = split(/\t/);
    $dictionary{$concept} = [@matches];
}



my $vocab = new Match($dictionaryfile);

my $result = "";

my @tokens = split(/\s+/, lc($input_text));
foreach my $idx ($vocab->match_idx(\@tokens)) {
    my ($left, $right) = @{ $idx };
    next if ($left == $right);       # malformed entity, ignore
    my $c = join("_", @tokens[$left .. $right-1]);
    if(exists $dictionary{$c}){
	foreach my $match (@{$dictionary{$c}}){
	    my($match_lang,$match_URI,$match_dict) = split('@@',$match);
	    if($match_lang eq $lang){
		$result .= $match_URI . "@@" . $match_dict . ":::";
	    }
	}
    }
}

print $result; # matchURI_1@@dict_1:::matchURI_2@@dict_2::: ... matchURI_N@@dict_N


