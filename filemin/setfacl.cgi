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
my $types;
$types = join(',',@types) if (@types);
$types .= " $extra" if ($extra);
my $args = "$action $types $recursive";
$args =~ s/\s+/ /g;
$args = &trim($args);
$args =~ s/[\`\$\;\/\'\"\?\%\&\#\*\(\)\+]//g;
foreach my $file (@files) {
    my $qfile = quotemeta("$path/$file");
    next if (!-r "$path/$file");
    my $fullcmd = "$cmd $args $qfile";
    my $out = &backquote_logged("$fullcmd 2>&1 >/dev/null </dev/null");
    if ($?) {
        $out =~ s/^setfacl: //;
        &error(&html_escape("$cmd $args $path/$file : $out"));
        }    
    }

&redirect("index.cgi?path=".&urlize($path));