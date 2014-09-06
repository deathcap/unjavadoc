#!/usr/bin/perl
use strict;
use warnings;

use HTML::TreeBuilder;
use File::Find qw(find);
use File::Path qw(make_path);
use File::Basename;

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

die "usage: $0 javadocs-directory out-root" if !@ARGV;

my ($root, $outroot) = @ARGV;
die "absolute path required, not $root" if $root !~ m/^\//;

# find class documentation files
find sub {
    my $path = $File::Find::name;
    my $file = $_;
    return if -d $file;

    my $base = $path;
    $base =~ s/$root//;
    return if $base !~ m(/);  # ignore root files, must be in subdirectory to be a class
    return if $base =~ m(/class-use/);
    return if $base =~ m(/package-);
    return if $base =~ m/^src-html\//;
    return if $base =~ m/^resources\//;

    print "$base\n";

    my $name = $base;
    $name =~ s/.html$//;

    unjd("$root$base", $name, $outroot);
}, $root;

sub unjd {
    my ($path, $name, $outroot) = @_;

    my $outfn = "$outroot$name.java";

    my $dir = dirname($outfn);
    make_path($dir);

    open(OUT, ">$outfn") || die "cannot open $outfn: $!";
    open(FH, "<$path") || die "cannot open $path: $!";

    my $method_accum = "";
    while(<FH>) {
        chomp;

        if ($_ eq '<!-- ======== START OF CLASS DATA ======== -->' .. $_ eq '<!-- =========== ENUM CONSTANT SUMMARY =========== -->') {
            if (m/<\/FONT>$/) {
                my $package = strip_html($_);
                print OUT "package $package;\n";
                print OUT "\n";
            }

            if (m/<DT><PRE>/) {
                my $html = $_;
                my $class = strip_html($html);

                $class =~ s/ extends Enum<([^<]+)>//;  # Java enums only implicitly extend java.lang.Enum

                print OUT "$class {\n";
                print OUT "\n";
            }
        }

        if ($_ eq '<!-- ============ ENUM CONSTANT DETAIL =========== -->' .. $_ eq '<!-- ============ METHOD DETAIL ========== -->') {
            if (m/<\/PRE>$/) {
                my $html = $_;
                my $decl = strip_html($html);

                # no modifiers allowed on enum constants, public static final Material foo; -> foo,
                my @words = split /\s+/, $decl;
                my $last = pop @words;
                $decl = "$last,";

                print OUT "\t$decl\n";
            }
            print OUT "\t;\n" if $_ eq '<!-- ============ METHOD DETAIL ========== -->';
        }

        if ($_ eq '<!-- ============ METHOD DETAIL ========== -->' .. $_ eq '<!-- ========= END OF CLASS DATA ========= -->') {
            #print OUT "Method detail: $_\n";
            $method_accum = "" if m/^<PRE>/;
            if (m/^<PRE>/ .. /<\/PRE>$/) {
                s/\s+/ /g;
                $method_accum .= $_;
            }

            if (m/<\/PRE>$/) {
                my $html = $method_accum;
                my $decl = strip_html($html);
                #print OUT "html: $html\n";
                print OUT "\n";
                print OUT "\t$decl {\n";
                my $return = default_return($decl);
                if (defined($return)) {
                    print OUT "\t\treturn $return;\n";
                }
                print OUT "\t}\n";
            }
        }
    }
    close(FH);
    print OUT "}\n";
}

