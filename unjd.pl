#!/usr/bin/perl
use strict;
use warnings;

use HTML::TreeBuilder;
use File::Find qw(find);
use File::Path qw(make_path);
use File::Basename;
use File::Slurp qw/read_file write_file/;

sub strip_html {
    my ($html) = @_;
    $html =~ s/&nbsp;/ /g;
    $html =~ s/<DT>/ /g;  # fix missing space after extends, implements
    my $tree = HTML::TreeBuilder->new();
    $tree->parse($html);
    return $tree->as_text();
}

sub default_return {
    my ($decl, $is_constructor) = @_;

    return undef if $is_constructor; # effectively void

    $decl =~ s/\s*(public|private|protected|static|final)\s*//g;
    $decl =~ s/\s*\@Deprecated\s*//g; # TODO: all annotations, regex
    my @words = split /\s+/, $decl;
    my $type = $words[0]; # first

    die "default_return($decl, $is_constructor) fail to match type" if !defined($type);

    my %defaults = (
        void => undef,
        byte => '0',
        char => q('\0'),
        int => '0',
        short => '0',
        long => '0',
        float => '0.0f',
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

open(CSV, ">api.csv") || die "cannot open api.csv: $!";

# find class documentation files
my @files;
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

    my $name = $base;
    $name =~ s/.html$//;

    push @files, $name;
}, $root;

# sort so inner classes (foo.bar) come after outer classes (foo)
@files = sort @files;

for my $name (@files) {
    print "$name\n";
    my @out = unjd($name);
    print CSV join("\n", @out), "\n\n";
}
close(CSV);

sub uniq {
    # http://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
    my %hash = map { $_, 1 } @_;
    return keys %hash;
}

sub unjd {
    my ($name) = @_;
    my $path = "$root$name.html";

    my $outfn = "$outroot$name.java";

    my $dir = dirname($outfn);
    make_path($dir);

    open(FH, "<$path") || die "cannot open $path: $!";

    my $out = "";
    my @out;
    my $method_accum = "";
    my $class_accum = "";
    my $class_declared = 0;
    my $class_name;
    my $is_interface = 0;
    my $is_enum = 0;
    my %imports;
    my $package_line = "";
    my $package_name;
    my $in_inherited = 0;
    while(<FH>) {
        chomp;

        while (m/title="(class|interface|enum|class or interface) in ([^"]+)">([^<]+)/g) {
            my $package = $2;
            my $symbol = $3;

            if ($symbol =~ m/^$package/) {  # already fully-qualified
                $imports{$symbol}++;
            } elsif ($symbol =~ m/^[a-z]/) {
                # lowercase symbol name, probably not actually a class we need to import
            } else {
                $imports{"$package.$symbol"}++ unless $in_inherited;
            }
        }

        $in_inherited = (m/Fields inherited from / .. $_ eq '<!-- ======== CONSTRUCTOR SUMMARY ======== -->');

        if ($_ eq '<!-- ======== START OF CLASS DATA ======== -->' .. $_ eq '<!-- =========== ENUM CONSTANT SUMMARY =========== -->') {
            $class_declared = 0 if $_ eq '<!-- ======== START OF CLASS DATA ======== -->';
            if (m/<\/FONT>$/) {
                my $package = strip_html($_);
                $package_line = "package $package;\n";
                $package_name = $package;
            }

            $class_accum = "" if m/<DT><PRE>/;
            if (!$class_declared && (m/^<DT><PRE>/ .. m/(<\/A>)?(&gt;)?<\/DL>$/)) {
                $class_accum .= "$_ ";

                if (m/(<\/A>)?(&gt;)?<\/DL>$/) {
                    my $html = $class_accum;
                    $class_accum =~ s/\s+/ /g;
                    my $class = strip_html($html);

                    $class =~ s/ extends Enum<([^<]+)>//;  # Java enums only implicitly extend java.lang.Enum

                    $class_name = $class;
                    $class_name =~ s/\s*(public|private|protected|static|final|class|enum|struct|interface|abstract)\s*//g;
                    $class_name =~ s/\s*(extends|implements).*//;

                    $is_interface = $class =~ m/\binterface\b/;
                    $is_enum = $class =~ m/\benum\b/;

                    $out .= "$class {\n";
                    $out .= "\n";
                    push @out, "class\t$class";
                    $class_declared = 1;  # only first match; other patterns are other class references
                }
            }
        }

        my $is_enum_constant = 0;
        if ($_ eq '<!-- ============ ENUM CONSTANT DETAIL =========== -->' .. $_ eq '<!-- ============ METHOD DETAIL ========== -->') {
            if (m/<\/PRE>$/) {
                my $html = $_;
                my $decl = strip_html($html);

                # no modifiers allowed on enum constants, public static final Material foo; -> foo,
                my @words = split /\s+/, $decl;
                my $last = pop @words;
                $decl = "$last,";

                $out .= "\t$decl\n";
                push @out, "const\t$last";
                $is_enum_constant = 1;
            }
            if ($_ eq '<!-- ============ METHOD DETAIL ========== -->') {
                $out .= "\t;\n";
                #push @out, "endconst";
            }
        }

        my $is_constructor = $_ eq '<!-- ========= CONSTRUCTOR DETAIL ======== -->' .. $_ eq '<!-- ========= METHOD DETAIL ========= -->';
        my $is_method = $_ eq '<!-- ============ METHOD DETAIL ========== -->' .. $_ eq '<!-- ========= END OF CLASS DATA ========= -->';
        $is_constructor = 0 if $is_method;
        if ($is_method || $is_constructor && $class_declared && !$is_enum_constant) {
            if (m/^<A NAME="([^"]+)"><!-- --><\/A><H3>/) {
                my $method_anchor = $1;    # name with fully-qualified type parameters TODO: but return value? may need to parse links instead
                my ($ignored_name, $param_list) = $method_anchor =~ m/^([^(]+)\(([^)]*)/;
                next if !defined($param_list);  # enum constant
                my @param_types = split /, /, $param_list;
                @param_types = map {
                    s/\[|\]//g; # array types to basic
                    s/\.\.\.//g; # variadic types to basic
                    $_ } @param_types; 

                # save fully-qualified type names for imports
                $imports{$_}++ foreach @param_types;
            }

            # <PRE></PRE> tag surrounding method declaration with return value, name, parameter short types, and parameter names
            $method_accum = "" if m/^<PRE>/;
            if (m/^<PRE>/ .. m/<\/PRE>$/) {
                $method_accum .= $_ . " ";
            }

            if (m/<\/PRE>$/) {
                my $html = $method_accum;
                $html =~ s/\s+/ /g;
                my $decl = strip_html($html);
                $decl =~ s/^\s+//g;

                my $method_name;

                ($method_name) = $decl =~ m/\s+(\w+)\(/;
                $method_name = "" if !defined($method_name);

                if ($is_enum) {
                    if ($method_name eq 'values' || $method_name eq 'valueOf') {
                        # javadocs include values() and valueOf() but they are implemented by Enum
                        next;
                    }
                }

                my $is_abstract = $decl =~ m/\babstract\b/;
                my $is_field = $decl !~ m/\(/;  # <!-- ============ FIELD DETAIL =========== --> ends up here too (hack)
                next if $is_abstract && $is_field;
                my $no_body = $is_interface || $is_abstract || $is_field;

                if ($no_body) {
                    if ($is_field && $decl) {
                        my $default = default_return($decl);  # initialize fields TODO: only if final?  && $decl =~ m/\bfinal\b/)
                        $out .= "\n\t$decl = $default;\n";
                        push @out, "field\t$decl\t$default";
                    } else {
                        if (length($decl)) {
                            $out .= "\n\t$decl;\n";
                            push @out, "field\t$decl";
                        }
                    }
                } else {
                    # method body
                    $out .= "\n\t$decl {\n";
                    my $return = default_return($decl, $is_constructor);
                    if (defined($return)) {
                        $out .= "\t\treturn $return;\n";
                        push @out, "method\t$decl\t$return";
                    } else {
                        push @out, "method\t$decl";
                    }
                    $out .= "\t}\n";
                }
            }
        }
    }
    $out .= "}\n";
    close(FH);

    if (keys %imports) {
        my @imports = sort keys %imports;
        @imports = grep { m/[.]/ && !m/[ ]/} @imports; # skip unqualified types (assume built-in Java, float etc.), and spaces (non-identifiers)
        @imports = grep { !m/^java\.lang\./ } @imports; # built-in types
        my $import_lines = "";
        for my $import (@imports) {
            $import_lines .= "import $import;\n";
            unshift @out, "typeref\t$import";
        }
        $out = "$import_lines\n\n$out";
    }

    if ($package_line) {
        $out = "$package_line\n$out";
        unshift @out, "scope\t$package_name";
    }

    if ($class_name =~ m/[.]/) {
        # inner class
        my @words = split m/[.]/, $class_name;
        my ($outer_class, $inner_class) = @words;

        $outer_class =~ s/\@Deprecated//; # TODO: remove all annotations

        # replace last path component to get outer class filename
        my $outer_path = $outfn;
        $outer_path =~ s/\/[^\/]+$//;;
        $outer_path .= "/$outer_class.java";

        print "OUTER: $outer_path of $outfn\n";

        # indent one level
        my @lines = split /\n/, $out;
        @lines = grep { !m/^package / } @lines;
        my @inner_imports = grep { m/^import / } @lines;  # need to move up
        my $inner_imports = join("\n", @inner_imports);
        @lines = grep { !m/^import / } @lines;
        @lines = map { "\t$_" } @lines;
        $out = join("\n", @lines);
        $out =~ s/$outer_class\.//g;  # outer.inner -> inner

        my $code = read_file($outer_path);
        $code =~ s/^(package ([^\n]+)\n\n)/$1$inner_imports\n/;  # inner imports at top, after package
        $code =~ s/}$//;
        # inner class at end of outer class declaration
        $code .= $out;
        $code .= "\n}\n";

        unshift @out, "outer\t$package_name.$outer_class";
        unshift @out, "inner\t1";

        write_file($outer_path, $code);
    } else {
        unshift @out, "outer\t$package_name.$class_name";
        unshift @out, "inner\t0";
        write_file($outfn, $out);
    }
    return @out;
}

