#!/usr/bin/perl
use strict;
use warnings;
use Data::Dumper;
use File::Path qw(make_path);
use File::Basename;

my (%files);
my ($filename, $package_name, @imports, $class_decl, @fields, @consts, @methods, $inner);

die "usage: $0 outdir < api.csv" if @ARGV != 1;
my $outroot = shift @ARGV;

# read API data into @classes
my $t = " " x 4;
while(<>) {
    chomp;
    if ($_ eq '') {
        my $data = {
            FILENAME => $filename,
            INNER => $inner,
            PACKAGE_NAME => $package_name,
            IMPORTS => [@imports],
            CLASS_DECL => $class_decl,
            FIELDS => [@fields],
            CONSTS => [@consts],
            METHODS => [@methods],
        };
        $files{$filename} = [] if !exists $files{$filename};
        push @{$files{$filename}}, $data;

        undef $filename;
        undef $inner;
        undef $package_name;
        undef $class_decl;
        @consts = ();
        @imports = ();
        @fields = ();
        @methods = ();
        next;
    }

    my @tokens = split /\t/;
    my $kind = $tokens[0];
    if ($kind eq 'outer') {
        $filename = $tokens[1];
        $filename =~ s/\./\//g;
        $filename = "$filename.java";
    } elsif ($kind eq 'inner') {
        $inner = $tokens[1];
    } elsif ($kind eq 'scope') {
        $package_name = $tokens[1];
    } elsif ($kind eq 'typeref') {
        push @imports, $tokens[1];
    } elsif ($kind eq 'class') {
        $class_decl = $tokens[1];
    } elsif ($kind eq 'field') {
        if (defined($tokens[2])) {
            push @fields, "$tokens[1] = $tokens[2]";
        } else {
            push @fields, $tokens[1];
        }
    } elsif ($kind eq 'const') {
        push @consts, $tokens[1];
    } elsif ($kind eq 'method') {
        if (defined($tokens[2])) {
            push @methods, "$tokens[1] {";
            push @methods, "${t}return $tokens[2];";
            push @methods, "}";
            push @methods, "";
        } else {
            push @methods, "$tokens[1];";
            push @methods, "";
        }
    } else {
        die "unrecognized line: |$kind|";
    }
}


sub uniq {
    # http://perldoc.perl.org/perlfaq4.html#How-can-I-remove-duplicate-elements-from-a-list-or-array%3f
    my %hash = map { $_, 1 } @_;
    return keys %hash;
}

# write
for my $filename (sort keys %files) {
    my $path = "$outroot/$filename";
    my $dir = dirname($path);
    make_path($dir);

    print "$filename\n";
    open(FH, ">$path") || die "cannot open $path: $!";

    my @classes = @{$files{$filename}};

    # gather all imports for outer and inner classes
    my @imports;
    for my $data (@classes) {
        push @imports, @{$data->{IMPORTS}};
    }
    @imports = uniq @imports;
    my $package;
    for my $data (@classes) {
        die "mismatched package name per file, $package ne $data->{PACKAGE_NAME}" if (defined($package) && $package ne $data->{PACKAGE_NAME});
        $package = $data->{PACKAGE_NAME}
    }
    my $imports = join("", map { "import $_;\n" } sort @imports);

    print FH <<EOF;
package $package;

$imports
EOF

    # each class
    for my $data (@classes) {
        my $consts = join("", map { "$t$_,\n" } @{$data->{CONSTS}}) . (@{$data->{CONSTS}} ? ";\n" : "");
        my $fields = join("", map { "$t$_;\n" } @{$data->{FIELDS}});
        my $methods = join("", map { length($_) ? "$t$_\n" : "\n" } @{$data->{METHODS}});
        my $indent = " " x ($data->{INNER} * 4);

        print FH <<EOF;
${indent}$data->{CLASS_DECL} {

$indent$consts
$indent$fields
$indent$methods
$indent}

EOF
    }

    close(FH);
}

