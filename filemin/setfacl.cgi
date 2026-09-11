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

# Parse the documented manual syntax without allowing arbitrary options
my @manual_entries;
if ($extra) {
	foreach my $entry (split(/\s+/, trim($extra))) {
		if ($entry =~ /\A(?:-m|-x|-b|-k)\z/) {
			&error('Invalid manual ACL')
				if ($action && $action ne $entry);
			$action ||= $entry;
			next;
			}
		if ($entry eq '-R') {
			$recursive = " -R";
			next;
			}
		&error('Invalid manual ACL')
			if ($entry !~ /:/ || $entry =~ /^-/);
		push(@manual_entries, $entry);
		}
	}
&error('Invalid ACL action')
	if (!defined($action) || $action !~ /\A(?:-m|-x|-b|-k)\z/);
&error('Invalid manual ACL')
	if (@manual_entries && ($action eq '-b' || $action eq '-k'));

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
push(@types, @manual_entries);
my $cmd = &has_command('setfacl');
error($text{'acls_error'}) if (!$cmd);

# Params are not accepted in clear mode
my $types;
if ($action ne '-b' && $action ne '-k') {
	$types = quotemeta(join(',',@types))
		if (@types);
	}
my $args = quotemeta($action).
	" ".$types." ".$recursive;
$args =~ s/\s+/ /g;
$args = &trim($args);
foreach my $file (@files) {
	my $full = &validate_filename_path($file);
	my $qfile = quotemeta($full);
	next if (!-r $full);
	my $fullcmd = "$cmd $args $qfile";
	my $out = &backquote_logged(
		"$fullcmd 2>&1 >/dev/null </dev/null");
	if ($?) {
		$out =~ s/^setfacl: //;
		&error(&html_escape(
			"$cmd $args $full : $out"));
		}
	}

&redirect("index.cgi?path=".&urlize($path));
