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

    if ($_ eq '<!-- ======== START OF CLASS DATA ======== -->' .. $_ eq '<!-- =========== ENUM CONSTANT SUMMARY =========== -->') {
        if (m/<DT><PRE>/) {
            my $html = $_;
            $html =~ s/<\/A><DT>/ /;  # fix missing space after extends
            my $class = strip_html($html);

            print "$class {\n";
            print "\n";
        }
    }

    if ($_ eq '<!-- ============ ENUM CONSTANT DETAIL =========== -->' .. $_ eq '<!-- ============ METHOD DETAIL ========== -->') {
        if (m/<\/PRE>$/) {
            my $html = $_;
            $html =~ s/&nbsp;/ /g;
            my $decl = strip_html($html);

            print "\t$decl;\n";
        }
    }

    if ($_ eq '<!-- ============ METHOD DETAIL ========== -->' .. $_ eq '<!-- ========= END OF CLASS DATA ========= -->') {
        #print "Method detail: $_\n";
        if (m/<\/PRE>$/) {
            my $html = $_;
            $html =~ s/&nbsp;/ /g;
            my $text = strip_html($html);
            #print "html: $html\n";
            print "\n";
            print "\t$text {\n";
            #print "\nreturn;\n"; // TODO: default return value
            print "\t}\n";
        }
    }
}

print "}\n";
