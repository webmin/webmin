#!/usr/local/bin/perl
# Create, update or delete a file set

require './bacula-backup-lib.pl';
&ReadParse();
$conf = &get_director_config();
$parent = &get_director_config_parent();
@filesets = &find("FileSet", $conf);

if (!$in{'new'}) {
	$fileset = &find_by("Name", $in{'old'}, \@filesets);
        $fileset || &error($text{'fileset_egone'});
	}
else {
	$fileset = { 'type' => 1,
		     'name' => 'FileSet',
		     'members' => [ ] };
	}

&lock_file($parent->{'file'});
if ($in{'delete'}) {
	# Just delete this one
	$name = &find_value("Name", $fileset->{'members'});
	$child = &find_dependency("FileSet", $name, [ "Job", "JobDefs" ], $conf);
	$child && &error(&text('fileset_echild', $child));
	&save_directive($conf, $parent, $fileset, undef, 0);
	}
else {
	# Validate and store inputs
	&error_setup($text{'fileset_err'});
	$in{'name'} =~ /\S/ || &error($text{'fileset_ename'});
	if ($in{'new'} || $in{'name'} ne $in{'old'}) {
		$clash = &find_by("Name", $in{'name'}, \@filesets);
		$clash && &error($text{'fileset_eclash'});
		}
	&save_directive($conf, $fileset, "Name", $in{'name'}, 1);

	# Save included files
	$in{'include'} =~ s/\r//g;
	if ($in{'include'} !~ /^\\\|/) {
		$in{'include'} =~ s/\\/\//g;
		}
	@include = split(/\n+/, $in{'include'});
	$inc = &find("Include", $fileset->{'members'});
	if (!$inc) {
		$inc = { 'name' => 'Include', 'type' => 1, 'members' => [ ] };
		&save_directive($conf, $fileset, undef, $inc, 1);
		}
	&save_directives($conf, $inc, "File", \@include, 2);
	$opts = &find("Options", $inc->{'members'});
	if (!$opts) {
		$opts = { 'name' => 'Options', 'type' => 1, 'members' => [ ] };
		&save_directive($conf, $inc, undef, $opts, 2);
		}
	&save_directive($conf, $opts, "signature",
			$in{'signature'} || undef, 3);

	# Save excluded files
	$in{'exclude'} =~ s/\r//g;
	if ($in{'exclude'} !~ /^\\\|/) {
		$in{'exclude'} =~ s/\\/\//g;
		}
	@exclude = split(/\n+/, $in{'exclude'});
	$exc = &find("Exclude", $fileset->{'members'});
	if (!$exc && @exclude) {
		$exc = { 'name' => 'Exclude', 'type' => 1, 'members' => [ ] };
		&save_directive($conf, $fileset, undef, $exc, 1);
		}
	if ($exc) {
		&save_directives($conf, $exc, "File", \@exclude, 2);
		}

	# Save compression level
	if ($in{'comp'}) {
		&save_directive($conf, $opts, "Compression", $in{'comp'}, 1);
		}
	else {
		&save_directive($conf, $opts, "Compression", undef);
		}

	&save_directive($conf, $opts, "OneFS", $in{'onefs'} || undef, 1);

	# Create or update
	if ($in{'new'}) {
		&save_directive($conf, $parent, undef, $fileset, 0);
		}
	}

&flush_file_lines();
&unlock_file($parent->{'file'});
&auto_apply_configuration();
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify",
	    "fileset", $in{'old'} || $in{'name'});
&redirect("list_filesets.cgi");

