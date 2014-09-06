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
    $html =~ s/<\/A><DT>/ /g;  # fix missing space after extends, implements
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
    return if $base =~ m(/doc-files/);
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

    open(FH, "<$path") || die "cannot open $path: $!";

    my $out = "";
    my $method_accum = "";
    my $class_accum = "";
    my $class_declared = 0;
    while(<FH>) {
        chomp;

        if ($_ eq '<!-- ======== START OF CLASS DATA ======== -->' .. $_ eq '<!-- =========== ENUM CONSTANT SUMMARY =========== -->') {
            $class_declared = 0 if $_ eq '<!-- ======== START OF CLASS DATA ======== -->';
            if (m/<\/FONT>$/) {
                my $package = strip_html($_);
                $out .= "package $package;\n";
                $out .= "\n";
            }

            $class_accum = "" if m/<DT><PRE>/;
            if (!$class_declared && (m/^<DT><PRE>/ .. m/(<\/A>)?(&gt;)?<\/DL>$/)) {
                $class_accum .= "$_ ";

                if (m/(<\/A>)?(&gt;)?<\/DL>$/) {
                    my $html = $class_accum;
                    $class_accum =~ s/\s+/ /g;
                    my $class = strip_html($html);

                    $class =~ s/ extends Enum<([^<]+)>//;  # Java enums only implicitly extend java.lang.Enum

                    $out .= "$class {\n";
                    $out .= "\n";
                    $class_declared = 1;  # only first match; other patterns are other class references
                }
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

                $out .= "\t$decl\n";
            }
            $out .= "\t;\n" if $_ eq '<!-- ============ METHOD DETAIL ========== -->';
        }

        if ($_ eq '<!-- ============ METHOD DETAIL ========== -->' .. $_ eq '<!-- ========= END OF CLASS DATA ========= -->') {
            $method_accum = "" if m/^<PRE>/;
            if (m/^<PRE>/ .. m/<\/PRE>$/) {
                $method_accum .= $_ . " ";
            }

            if (m/<\/PRE>$/) {
                my $html = $method_accum;
                $html =~ s/\s+/ /g;
                my $decl = strip_html($html);
                $out .= "\n";
                $out .= "\t$decl {\n";
                my $return = default_return($decl);
                if (defined($return)) {
                    $out .= "\t\treturn $return;\n";
                }
                $out .= "\t}\n";
            }
        }
    }
    $out .= "}\n";
    close(FH);
    open(OUT, ">$outfn") || die "cannot open $outfn: $!";
    print OUT $out;
    close(OUT);
}

