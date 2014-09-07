#!/usr/bin/perl
use strict;
use warnings;

while(<>) {
    chomp;
    my @tokens = split /\t/;
    my $kind = $tokens[0];
    if ($kind eq 'outer') {
    } elsif ($kind eq 'scope') {
        print "package $kind;\n";
    } elsif ($kind eq 'typeref') {
        print "import $tokens[1];\n";
    } elsif ($kind eq 'class') {
        print "class $tokens[1] {\n";
    } elsif ($kind eq 'field') {
        print "\t$tokens[1] = $tokens[2];\n";
    } elsif ($kind eq 'const') {
        print "\t$tokens[1],\n";
    } elsif ($kind eq 'method') {
        print "\t$tokens[1] {";
        print "\t\treturn $tokens[1];\n" if defined($tokens[1]);
        print "\t}\n";
    } else {
        die "unrecognized line $kind";
    }
}
