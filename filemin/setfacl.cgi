#!/usr/local/bin/perl

require './filemin-lib.pl';
&ReadParse();
get_paths();

# Files to work on (arr)
my @files = split(/\0/, $in{'name'});
# Action
my $action = $in{'action'};
# Permission
my $perms = $in{'perms'};
# User
my $user = $in{'user'};
# Group
my $group = $in{'group'};
# Recursive
my $recursive = $in{'recursive'} ? " -R" : "";
# Manual
my $extra = $in{'manual'};
# Apply to (arr)
my @apply_to = split(/\0/, $in{'apply_to'});

# Delete doesn't allow perms
$perms = "" if ($action eq '-x');

# Build params
my @types;
foreach my $type (@apply_to) {
    if ($user && $type eq 'u') {
        push(@types, "u:${user}:${perms}");
        }
    if ($group && $type eq 'g') {
        push(@types, "g:${group}:${perms}");
        }
    if ($type =~ /^m|o$/) {
        push(@types, "${type}::${perms}");
        }
    }
my $cmd = &has_command('setfacl');
error($text{'acls_error'}) if (!$cmd);

# Params are not accepted in clear mode
my $types;
if ($action ne '-b' && $action ne '-k') {
    $types = quotemeta(join(',',@types)) if (@types);
    if ($extra) {
        my @extra = split(/\s/, $extra);
        @extra = map { quotemeta($_) } @extra;
        $types .= " ".join(' ', @extra) ;
        }
    }
my $args = quotemeta($action)." ".$types." ".$recursive;
$args =~ s/\s+/ /g;
$args = &trim($args);
foreach my $file (@files) {
    my $qfile = quotemeta("$cwd/$file");
    next if (!-r "$cwd/$file");
    my $fullcmd = "$cmd $args $qfile";
    my $out = &backquote_logged("$fullcmd 2>&1 >/dev/null </dev/null");
    if ($?) {
        $out =~ s/^setfacl: //;
        &error(&html_escape("$cmd $args $cwd/$file : $out"));
        }    
    }

&redirect("index.cgi?path=".&urlize($path));