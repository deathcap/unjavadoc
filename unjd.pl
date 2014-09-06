#!/usr/bin/perl
use strict;
use warnings;

use HTML::TreeBuilder;

sub strip_html {
    my ($html) = @_;
    $html =~ s/&nbsp;/ /g;
    $html =~ s/<\/A><DT>/ /;  # fix missing space after extends
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($html);
    return $tree->as_text();
}

sub default_return {
    my ($decl) = @_;

    $decl =~ s/\s*(public|private|protected|static)\s*//g;
    my @words = split /\s+/, $decl;
    my $type = $words[0]; # first

    my %defaults = (
        void => undef,
        int => '0',
        short => '0',
        long => '0',
        float => '0.0',
        double => '0.0',
        boolean => 'false',
    );

    if (exists $defaults{$type}) {
        return $defaults{$type};
    } else {
        # object reference types
        # TODO: array type[], return new T()
        return "null";
    }
}

while(<>) {
    chomp;

    if ($_ eq '<!-- ======== START OF CLASS DATA ======== -->' .. $_ eq '<!-- =========== ENUM CONSTANT SUMMARY =========== -->') {
        if (m/<\/FONT>$/) {
            my $package = strip_html($_);
            print "package $package;\n";
            print "\n";
        }

        if (m/<DT><PRE>/) {
            my $html = $_;
            my $class = strip_html($html);

            print "$class {\n";
            print "\n";
        }
    }

    if ($_ eq '<!-- ============ ENUM CONSTANT DETAIL =========== -->' .. $_ eq '<!-- ============ METHOD DETAIL ========== -->') {
        if (m/<\/PRE>$/) {
            my $html = $_;
            my $decl = strip_html($html);

            print "\t$decl;\n";
        }
    }

    if ($_ eq '<!-- ============ METHOD DETAIL ========== -->' .. $_ eq '<!-- ========= END OF CLASS DATA ========= -->') {
        #print "Method detail: $_\n";
        if (m/<\/PRE>$/) {
            my $html = $_;
            my $decl = strip_html($html);
            #print "html: $html\n";
            print "\n";
            print "\t$decl {\n";
            my $return = default_return($decl);
            if (defined($return)) {
                print "\t\treturn $return;\n";
            }
            print "\t}\n";
        }
    }
}

print "}\n";
