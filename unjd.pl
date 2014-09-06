#!/usr/bin/perl
use strict;
use warnings;

use HTML::TreeBuilder;

sub strip_html {
    my ($html) = @_;
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($html);
    return $tree->as_text();
}

my $fn = '../jd-bukkit/jd.bukkit.org/rb/apidocs/org/bukkit/Material.html';
open(FH, "<$fn") || die "failed to open $fn: $!";
while(<FH>) {
    chomp;
    if ($_ eq '<!-- ============ METHOD DETAIL ========== -->' .. $_ eq '<!-- ========= END OF CLASS DATA ========= -->') {
        #print "Method detail: $_\n";
        if (m/<\/PRE>$/) {
            my $html = $_;
            my $text = strip_html($html);
            #print "html: $html\n";
            print "text: $text\n";
        }
    }
}
